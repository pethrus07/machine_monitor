import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:logging/logging.dart';

/// Cliente Modbus TCP/IP de baixo nível.
///
/// Fala o protocolo MBAP direto sobre um [Socket]: monta os frames, casa cada
/// resposta com sua requisição pelo Transaction ID e expõe as funções Modbus
/// usadas pelo app. É genérico — não sabe nada sobre máquinas, OEE ou TEX.
///
/// Responsabilidades:
///   • conexão / reconexão automática e timeout;
///   • serialização das escritas (uma de cada vez) via [_AsyncLock];
///   • leituras contínuas como [Stream] cancelável.
class ModbusClientTcp {
  ModbusClientTcp({
    this.unitId = 1,
    this.responseTimeout = const Duration(seconds: 5),
    this.connectionTimeout = const Duration(seconds: 10),
    this.isLittleEndian = true,
  });

  final Logger _log = Logger('ModbusClientTcp');

  int unitId;
  Duration responseTimeout;
  Duration connectionTimeout;
  bool isLittleEndian;

  Socket? _socket;
  StreamSubscription<Uint8List>? _socketSub;
  final List<int> _rxBuffer = [];

  int _transactionId = 0;
  final Map<int, _PendingRequest> _pending = {};
  final _sendLock = _AsyncLock();

  String? _host;
  int? _port;
  bool _manualDisconnect = false;

  /// Controllers das leituras contínuas — fechados em [disconnect].
  final List<StreamController<dynamic>> _activeStreams = [];

  bool isConnected() => _socket != null;

  // ── Conexão ──────────────────────────────────────────────────────────────────

  Future<void> connect({required String host, required int port}) async {
    _host = host;
    _port = port;
    _manualDisconnect = false;

    try {
      _log.info('Conectando a $host:$port...');
      _socket = await Socket.connect(host, port, timeout: connectionTimeout);

      _socketSub = _socket!.listen(
        _handleData,
        onError: (Object error) {
          _log.severe('Erro no socket ($host:$port): $error');
          _socket = null;
          _failPending('Erro de socket');
        },
        onDone: () {
          _log.info('Socket encerrado ($host:$port)');
          _socket = null;
          _failPending('Conexão encerrada');
        },
        cancelOnError: true,
      );

      _log.info('Conectado a $host:$port');
    } catch (e) {
      _log.severe('Falha ao conectar em $host:$port → $e');
      _socket = null;
      rethrow;
    }
  }

  Future<void> disconnect() async {
    _manualDisconnect = true;

    for (final controller in _activeStreams) {
      await controller.close();
    }
    _activeStreams.clear();

    try {
      await _socketSub?.cancel();
      _socketSub = null;
      await _socket?.close();
    } catch (e) {
      _log.severe('Erro ao desconectar: $e');
    } finally {
      _socket = null;
      _rxBuffer.clear();
      _failPending('Desconectado');
      _log.info('Desconectado');
    }
  }

  /// Reconecta se o socket caiu e a queda não foi intencional.
  Future<void> _ensureConnected() async {
    if (_socket == null &&
        _host != null &&
        _port != null &&
        !_manualDisconnect) {
      _log.info('Reconectando a $_host:$_port...');
      await connect(host: _host!, port: _port!);
    }
  }

  void _failPending(String reason) {
    for (final pending in _pending.values) {
      pending.timer.cancel();
      if (!pending.completer.isCompleted) {
        pending.completer.completeError(reason);
      }
    }
    _pending.clear();
  }

  // ── Recepção (montagem de frames MBAP) ──────────────────────────────────────

  void _handleData(Uint8List data) {
    _rxBuffer.addAll(data);

    // O cabeçalho MBAP tem 7 bytes; o campo "length" (bytes 4-5) cobre tudo a
    // partir do unitId, então o frame completo tem 6 + length bytes.
    while (_rxBuffer.length >= 8) {
      final transactionId = (_rxBuffer[0] << 8) | _rxBuffer[1];
      final length = (_rxBuffer[4] << 8) | _rxBuffer[5];
      final totalLength = 6 + length;

      if (_rxBuffer.length < totalLength) break;

      final frame = _rxBuffer.sublist(0, totalLength);
      _rxBuffer.removeRange(0, totalLength);

      final pending = _pending.remove(transactionId);
      if (pending == null) {
        _log.warning('Resposta sem requisição (TID $transactionId)');
        continue;
      }
      pending.timer.cancel();
      if (!pending.completer.isCompleted) {
        pending.completer.complete(frame);
      }
    }
  }

  // ── Envio ────────────────────────────────────────────────────────────────────

  Future<List<int>> _send(List<int> requestData) async {
    await _ensureConnected();
    final socket = _socket;
    if (socket == null) throw Exception('Socket não disponível');

    _transactionId = _transactionId >= 65535 ? 1 : _transactionId + 1;
    final txId = _transactionId;

    final request = Uint8List.fromList(requestData)
      ..[0] = (txId >> 8) & 0xFF
      ..[1] = txId & 0xFF;

    final completer = Completer<List<int>>();
    final timer = Timer(responseTimeout, () {
      final pending = _pending.remove(txId);
      if (pending != null && !pending.completer.isCompleted) {
        pending.completer.completeError(
          'Timeout (${responseTimeout.inSeconds}s) no TID $txId',
        );
      }
    });
    _pending[txId] = _PendingRequest(completer, timer);

    try {
      // Uma escrita por vez: evita intercalar bytes de frames diferentes.
      await _sendLock.synchronized(() async {
        socket.add(request);
        await socket.flush();
      });
      _log.fine('Enviado TID $txId');
      return await completer.future;
    } catch (e) {
      timer.cancel();
      _pending.remove(txId);
      rethrow;
    }
  }

  List<int> _applyEndianness(List<int> registers) {
    if (!isLittleEndian) return registers;
    return registers.map(_swapBytes).toList();
  }

  int _swapBytes(int value) =>
      ((value & 0xFF) << 8) | ((value >> 8) & 0xFF);

  // ── Funções Modbus ───────────────────────────────────────────────────────────

  Future<List<bool>> fn01ReadCoils({
    required int startAddress,
    required int count,
  }) =>
      _readBits(funcCode: 0x01, startAddress: startAddress, count: count);

  Future<List<bool>> fn02ReadDiscreteInputs({
    required int startAddress,
    required int count,
  }) =>
      _readBits(funcCode: 0x02, startAddress: startAddress, count: count);

  Future<List<int>> fn03ReadHoldingRegisters({
    required int startAddress,
    required int quantity,
  }) =>
      _readRegisters(
          funcCode: 0x03, startAddress: startAddress, quantity: quantity);

  Future<List<int>> fn04ReadInputRegisters({
    required int startAddress,
    required int quantity,
  }) =>
      _readRegisters(
          funcCode: 0x04, startAddress: startAddress, quantity: quantity);

  Future<bool> fn05WriteSingleCoil({
    required int address,
    required bool value,
  }) async {
    try {
      final response = await _send([
        0, 0, 0, 0, 0, 6, unitId, 0x05,
        (address >> 8) & 0xFF, address & 0xFF,
        value ? 0xFF : 0x00, 0x00,
      ]);
      return response.length >= 12 && response[7] == 0x05;
    } catch (e) {
      _log.severe('Erro ao escrever coil $address: $e');
      return false;
    }
  }

  Future<bool> fn06WriteSingleRegister({
    required int address,
    required int value,
  }) async {
    try {
      final data = isLittleEndian ? _swapBytes(value) : value;
      final response = await _send([
        0, 0, 0, 0, 0, 6, unitId, 0x06,
        (address >> 8) & 0xFF, address & 0xFF,
        (data >> 8) & 0xFF, data & 0xFF,
      ]);
      return response.length >= 12 && response[7] == 0x06;
    } catch (e) {
      _log.severe('Erro ao escrever register $address: $e');
      return false;
    }
  }

  Future<bool> fn15WriteMultipleCoils({
    required int startAddress,
    required List<bool> values,
  }) async {
    try {
      final byteCount = (values.length + 7) ~/ 8;
      final coilBytes = List<int>.filled(byteCount, 0);
      for (var i = 0; i < values.length; i++) {
        if (values[i]) coilBytes[i ~/ 8] |= (1 << (i % 8));
      }
      final response = await _send([
        0, 0, 0, 0, 0, (5 + byteCount) & 0xFF, unitId, 0x0F,
        (startAddress >> 8) & 0xFF, startAddress & 0xFF,
        (values.length >> 8) & 0xFF, values.length & 0xFF,
        byteCount, ...coilBytes,
      ]);
      return response.length >= 12 && response[7] == 0x0F;
    } catch (e) {
      _log.severe('Erro ao escrever múltiplos coils: $e');
      return false;
    }
  }

  Future<bool> fn16WriteMultipleRegisters({
    required int startAddress,
    required List<int> values,
  }) async {
    try {
      final registerBytes = <int>[];
      for (final value in values) {
        final data = isLittleEndian ? _swapBytes(value) : value;
        registerBytes
          ..add((data >> 8) & 0xFF)
          ..add(data & 0xFF);
      }
      final byteCount = registerBytes.length;
      final response = await _send([
        0, 0, 0, 0, 0, (5 + byteCount) & 0xFF, unitId, 0x10,
        (startAddress >> 8) & 0xFF, startAddress & 0xFF,
        (values.length >> 8) & 0xFF, values.length & 0xFF,
        byteCount, ...registerBytes,
      ]);
      return response.length >= 12 && response[7] == 0x10;
    } catch (e) {
      _log.severe('Erro ao escrever múltiplos registers: $e');
      return false;
    }
  }

  /// Implementação comum das funções de leitura de bits (01/02).
  Future<List<bool>> _readBits({
    required int funcCode,
    required int startAddress,
    required int count,
  }) async {
    try {
      final response = await _send([
        0, 0, 0, 0, 0, 6, unitId, funcCode,
        (startAddress >> 8) & 0xFF, startAddress & 0xFF,
        (count >> 8) & 0xFF, count & 0xFF,
      ]);
      if (response.length < 9 || response[7] != funcCode) return [];
      final byteCount = response[8];
      if (response.length < 9 + byteCount) return [];

      final bytes = response.sublist(9, 9 + byteCount);
      return List<bool>.generate(count, (i) {
        final byteIndex = i ~/ 8;
        final bitIndex = i % 8;
        return byteIndex < bytes.length &&
            (bytes[byteIndex] & (1 << bitIndex)) != 0;
      });
    } catch (e) {
      _log.severe('Erro ao ler bits (fn$funcCode): $e');
      return [];
    }
  }

  /// Implementação comum das funções de leitura de registradores (03/04).
  Future<List<int>> _readRegisters({
    required int funcCode,
    required int startAddress,
    required int quantity,
  }) async {
    try {
      final response = await _send([
        0, 0, 0, 0, 0, 6, unitId, funcCode,
        (startAddress >> 8) & 0xFF, startAddress & 0xFF,
        (quantity >> 8) & 0xFF, quantity & 0xFF,
      ]);
      if (response.length < 9 || response[7] != funcCode) return [];
      final byteCount = response[8];
      if (response.length < 9 + byteCount) return [];

      final bytes = response.sublist(9, 9 + byteCount);
      final registers = <int>[];
      for (var i = 0; i + 1 < bytes.length; i += 2) {
        registers.add((bytes[i] << 8) | bytes[i + 1]);
      }
      return _applyEndianness(registers);
    } catch (e) {
      _log.severe('Erro ao ler registers (fn$funcCode): $e');
      return [];
    }
  }

  // ── Leituras contínuas ───────────────────────────────────────────────────────

  Stream<List<bool>> continuousReadCoils({
    required int startAddress,
    required int count,
    Duration interval = const Duration(seconds: 1),
  }) =>
      _poll<List<bool>>(
        interval,
        () => fn01ReadCoils(startAddress: startAddress, count: count),
      );

  Stream<List<int>> continuousReadHoldingRegisters({
    required int startAddress,
    required int quantity,
    Duration interval = const Duration(seconds: 1),
  }) =>
      _poll<List<int>>(
        interval,
        () => fn03ReadHoldingRegisters(
            startAddress: startAddress, quantity: quantity),
      );

  /// Fábrica genérica de leitura contínua: dispara [read] a cada [interval] e
  /// emite o resultado no stream até o controller ser fechado ou a conexão cair.
  Stream<T> _poll<T>(Duration interval, Future<T> Function() read) {
    final controller = StreamController<T>();
    _activeStreams.add(controller);

    final timer = Timer.periodic(interval, (timer) async {
      if (controller.isClosed || _manualDisconnect) {
        timer.cancel();
        return;
      }
      try {
        final value = await read();
        if (!controller.isClosed) controller.add(value);
      } catch (e) {
        if (!controller.isClosed) controller.addError(e);
      }
    });

    controller.onCancel = () => timer.cancel();
    return controller.stream;
  }
}

class _PendingRequest {
  final Completer<List<int>> completer;
  final Timer timer;
  _PendingRequest(this.completer, this.timer);
}

/// Mutex simples para garantir uma escrita no socket por vez.
class _AsyncLock {
  Future<void>? _current;

  Future<T> synchronized<T>(Future<T> Function() action) async {
    while (_current != null) {
      await _current;
    }
    final completer = Completer<void>();
    _current = completer.future;
    try {
      return await action();
    } finally {
      completer.complete();
      _current = null;
    }
  }
}
