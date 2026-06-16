import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:logging/logging.dart';

class ModbusClientTcp {
  Socket? _socket;
  final Logger _logger = Logger('ModbusClientTcp');

  int unitId;
  Duration responseTimeout;
  Duration connectionTimeout;
  bool isLittleEndian;

  int _transactionId = 0;
  final Map<int, _PendingRequest> _pendingRequests = {};
  StreamSubscription? _socketSubscription;
  final List<int> _responseBuffer = [];

  final _sendLock = _AsyncLock();

  String? _host;
  int? _port;
  bool _manualDisconnect = false;

  // ✅ Controle dos Streams contínuos
  final _activeStreams = <StreamController>[];

  ModbusClientTcp({
    this.unitId = 1,
    this.responseTimeout = const Duration(seconds: 5),
    this.connectionTimeout = const Duration(seconds: 10),
    this.isLittleEndian = false,
  });

  Future<void> connect({required String host, required int port}) async {
    try {
      _host = host;
      _port = port;
      _manualDisconnect = false;
      _logger.info('Conectando a $host:$port...');

      _socket = await Socket.connect(host, port, timeout: connectionTimeout);

      _socketSubscription = _socket!.listen(
        _handleResponse,
        onError: (error) {
          _logger.severe('Erro no socket: $error');
          _socket = null;
          _clearPendingRequests();
        },
        onDone: () {
          _logger.info('Socket fechado');
          _socket = null;
          _clearPendingRequests();
        },
        cancelOnError: true,
      );

      _logger.info('✅ Conectado com sucesso a $host:$port');
    } catch (e) {
      _logger.severe('❌ Erro ao conectar: $e');
      _socket = null;
      rethrow;
    }
  }

  Future<void> disconnect() async {
    _manualDisconnect = true;

    // ✅ Cancelar todos os streams contínuos
    for (var controller in _activeStreams) {
      await controller.close();
    }
    _activeStreams.clear();

    try {
      await _socketSubscription?.cancel();
      _socketSubscription = null;

      if (_socket != null) {
        await _socket!.close();
        _socket = null;
      }

      _responseBuffer.clear();
      _clearPendingRequests();
      _logger.info('✅ Desconectado');
    } catch (e) {
      _logger.severe('Erro ao desconectar: $e');
    }
  }

  bool isConnected() => _socket != null;

  void _clearPendingRequests() {
    for (var pending in _pendingRequests.values) {
      pending.timer.cancel();
      if (!pending.completer.isCompleted) {
        pending.completer.completeError('Conexão perdida');
      }
    }
    _pendingRequests.clear();
  }

  void _handleResponse(List<int> data) {
    _responseBuffer.addAll(data);

    while (_responseBuffer.length >= 8) {
      int transactionId = (_responseBuffer[0] << 8) | _responseBuffer[1];
      int length = (_responseBuffer[4] << 8) | _responseBuffer[5];
      int totalLength = 6 + length;

      if (_responseBuffer.length >= totalLength) {
        List<int> response = _responseBuffer.sublist(0, totalLength);
        _responseBuffer.removeRange(0, totalLength);

        if (_pendingRequests.containsKey(transactionId)) {
          final pending = _pendingRequests.remove(transactionId)!;
          pending.timer.cancel();
          if (!pending.completer.isCompleted) {
            pending.completer.complete(response);
          }
        } else {
          _logger.warning(
            '⚠️ Resposta recebida para Transaction ID $transactionId não encontrado',
          );
        }
      } else {
        break;
      }
    }
  }

  Future<List<int>> _sendRequest(Uint8List requestData) async {
    await _ensureConnected();

    if (_socket == null) {
      throw Exception('Socket não disponível');
    }

    _transactionId++;
    if (_transactionId > 65535) _transactionId = 1;

    int txId = _transactionId;

    final request = Uint8List.fromList(requestData);
    request[0] = (txId >> 8) & 0xFF;
    request[1] = txId & 0xFF;

    final completer = Completer<List<int>>();

    final timer = Timer(responseTimeout, () {
      final pending = _pendingRequests.remove(txId);
      if (pending != null && !pending.completer.isCompleted) {
        pending.completer.completeError(
          'Timeout (${responseTimeout.inSeconds}s) para Transaction ID $txId',
        );
      }
    });

    _pendingRequests[txId] = _PendingRequest(completer, timer);

    try {
      await _sendLock.synchronized(() async {
        _socket!.add(request);
        await _socket!.flush();
      });

      _logger.fine('📤 Enviado Transaction ID: $txId');

      return await completer.future;
    } catch (e) {
      timer.cancel();
      _pendingRequests.remove(txId);
      rethrow;
    }
  }

  Future<void> _ensureConnected() async {
    if (_socket == null &&
        _host != null &&
        _port != null &&
        !_manualDisconnect) {
      _logger.info('Reconectando...');
      await connect(host: _host!, port: _port!);
    }
  }

  List<int> _applyEndianness(List<int> data) {
    if (!isLittleEndian || data.length < 2) return data;
    final result = <int>[];
    for (int i = 0; i < data.length; i += 2) {
      if (i + 1 < data.length) {
        result.add(data[i + 1]);
        result.add(data[i]);
      } else {
        result.add(data[i]);
      }
    }
    return result;
  }

  Future<List<bool>> fn01ReadCoils({
    required int startAddress,
    required int count,
  }) async {
    try {
      final request = Uint8List.fromList([
        0x00,
        0x00,
        0x00,
        0x00,
        0x00,
        0x06,
        unitId,
        0x01,
        (startAddress >> 8) & 0xFF,
        startAddress & 0xFF,
        (count >> 8) & 0xFF,
        count & 0xFF,
      ]);
      final response = await _sendRequest(request);
      if (response.length >= 9 && response[7] == 0x01) {
        final byteCount = response[8];
        if (response.length >= (9 + byteCount)) {
          final coilBytes = response.sublist(9, 9 + byteCount);
          final coils = <bool>[];
          for (int i = 0; i < count; i++) {
            final byteIndex = i ~/ 8;
            final bitIndex = i % 8;
            coils.add(
              byteIndex < coilBytes.length &&
                  (coilBytes[byteIndex] & (1 << bitIndex)) != 0,
            );
          }
          return coils;
        }
      }
      return [];
    } catch (e) {
      _logger.severe('Erro ao ler coils: $e');
      return [];
    }
  }

  Future<List<bool>> fn02ReadDiscreteInputs({
    required int startAddress,
    required int count,
  }) async {
    try {
      final request = Uint8List.fromList([
        0x00,
        0x00,
        0x00,
        0x00,
        0x00,
        0x06,
        unitId,
        0x02,
        (startAddress >> 8) & 0xFF,
        startAddress & 0xFF,
        (count >> 8) & 0xFF,
        count & 0xFF,
      ]);
      final response = await _sendRequest(request);
      if (response.length >= 9 && response[7] == 0x02) {
        final byteCount = response[8];
        if (response.length >= (9 + byteCount)) {
          final inputBytes = response.sublist(9, 9 + byteCount);
          final inputs = <bool>[];
          for (int i = 0; i < count; i++) {
            final byteIndex = i ~/ 8;
            final bitIndex = i % 8;
            inputs.add(
              byteIndex < inputBytes.length &&
                  (inputBytes[byteIndex] & (1 << bitIndex)) != 0,
            );
          }
          return inputs;
        }
      }
      return [];
    } catch (e) {
      _logger.severe('Erro ao ler discrete inputs: $e');
      return [];
    }
  }

  Future<List<int>> fn03ReadHoldingRegisters({
    required int startAddress,
    required int quantity,
  }) async {
    try {
      final request = Uint8List.fromList([
        0x00,
        0x00,
        0x00,
        0x00,
        0x00,
        0x06,
        unitId,
        0x03,
        (startAddress >> 8) & 0xFF,
        startAddress & 0xFF,
        (quantity >> 8) & 0xFF,
        quantity & 0xFF,
      ]);
      final response = await _sendRequest(request);
      if (response.length >= 9 && response[7] == 0x03) {
        final byteCount = response[8];
        if (response.length >= (9 + byteCount)) {
          final registerBytes = response.sublist(9, 9 + byteCount);
          final registers = <int>[];
          for (int i = 0; i < byteCount; i += 2) {
            if (i + 1 < registerBytes.length) {
              registers.add((registerBytes[i] << 8) | registerBytes[i + 1]);
            }
          }
          return _applyEndianness(registers);
        }
      }
      return [];
    } catch (e) {
      _logger.severe('Erro ao ler holding registers: $e');
      return [];
    }
  }

  Future<List<int>> fn04ReadInputRegisters({
    required int startAddress,
    required int quantity,
  }) async {
    try {
      final request = Uint8List.fromList([
        0x00,
        0x00,
        0x00,
        0x00,
        0x00,
        0x06,
        unitId,
        0x04,
        (startAddress >> 8) & 0xFF,
        startAddress & 0xFF,
        (quantity >> 8) & 0xFF,
        quantity & 0xFF,
      ]);
      final response = await _sendRequest(request);
      if (response.length >= 9 && response[7] == 0x04) {
        final byteCount = response[8];
        if (response.length >= (9 + byteCount)) {
          final registerBytes = response.sublist(9, 9 + byteCount);
          final registers = <int>[];
          for (int i = 0; i < byteCount; i += 2) {
            if (i + 1 < registerBytes.length) {
              registers.add((registerBytes[i] << 8) | registerBytes[i + 1]);
            }
          }
          return _applyEndianness(registers);
        }
      }
      return [];
    } catch (e) {
      _logger.severe('Erro ao ler input registers: $e');
      return [];
    }
  }

  Future<bool> fn05WriteSingleCoil({
    required int address,
    required bool value,
  }) async {
    try {
      final request = Uint8List.fromList([
        0x00,
        0x00,
        0x00,
        0x00,
        0x00,
        0x06,
        unitId,
        0x05,
        (address >> 8) & 0xFF,
        address & 0xFF,
        value ? 0xFF : 0x00,
        0x00,
      ]);
      final response = await _sendRequest(request);
      return response.length >= 12 && response[7] == 0x05;
    } catch (e) {
      _logger.severe('Erro ao escrever coil: $e');
      return false;
    }
  }

  Future<bool> fn06WriteSingleRegister({
    required int address,
    required int value,
  }) async {
    try {
      final dataToWrite = isLittleEndian ? _swapBytes(value) : value;
      final request = Uint8List.fromList([
        0x00,
        0x00,
        0x00,
        0x00,
        0x00,
        0x06,
        unitId,
        0x06,
        (address >> 8) & 0xFF,
        address & 0xFF,
        (dataToWrite >> 8) & 0xFF,
        dataToWrite & 0xFF,
      ]);
      final response = await _sendRequest(request);
      return response.length >= 12 && response[7] == 0x06;
    } catch (e) {
      _logger.severe('Erro ao escrever register: $e');
      return false;
    }
  }

  Future<bool> fn15WriteMultipleCoils({
    required int startAddress,
    required List<bool> values,
  }) async {
    try {
      final byteCount = (values.length + 7) ~/ 8;
      final coilBytes = <int>[byteCount];
      for (int i = 0; i < values.length; i++) {
        final byteIndex = (i ~/ 8) + 1;
        final bitIndex = i % 8;
        while (coilBytes.length <= byteIndex) coilBytes.add(0);
        if (values[i]) coilBytes[byteIndex] |= (1 << bitIndex);
      }
      final request = <int>[
        0x00,
        0x00,
        0x00,
        0x00,
        0x00,
        (5 + byteCount) & 0xFF,
        unitId,
        0x0F,
        (startAddress >> 8) & 0xFF,
        startAddress & 0xFF,
        (values.length >> 8) & 0xFF,
        values.length & 0xFF,
        ...coilBytes,
      ];
      final response = await _sendRequest(Uint8List.fromList(request));
      return response.length >= 12 && response[7] == 0x0F;
    } catch (e) {
      _logger.severe('Erro ao escrever múltiplos coils: $e');
      return false;
    }
  }

  Future<bool> fn16WriteMultipleRegisters({
    required int startAddress,
    required List<int> values,
  }) async {
    try {
      final byteCount = values.length * 2;
      final registerBytes = <int>[];
      for (final value in values) {
        final dataToWrite = isLittleEndian ? _swapBytes(value) : value;
        registerBytes.add((dataToWrite >> 8) & 0xFF);
        registerBytes.add(dataToWrite & 0xFF);
      }
      final request = <int>[
        0x00,
        0x00,
        0x00,
        0x00,
        0x00,
        (5 + byteCount) & 0xFF,
        unitId,
        0x10,
        (startAddress >> 8) & 0xFF,
        startAddress & 0xFF,
        (values.length >> 8) & 0xFF,
        values.length & 0xFF,
        byteCount,
        ...registerBytes,
      ];
      final response = await _sendRequest(Uint8List.fromList(request));
      return response.length >= 12 && response[7] == 0x10;
    } catch (e) {
      _logger.severe('Erro ao escrever múltiplos registers: $e');
      return false;
    }
  }

  int _swapBytes(int value) {
    return ((value & 0xFF) << 8) | ((value >> 8) & 0xFF);
  }

  // ✅ Streams contínuos agora são canceláveis
  Stream<List<bool>> continuousReadCoils({
    required int startAddress,
    required int count,
    Duration interval = const Duration(seconds: 1),
  }) {
    final controller = StreamController<List<bool>>();
    _activeStreams.add(controller);

    Timer.periodic(interval, (timer) async {
      if (controller.isClosed || _manualDisconnect) {
        timer.cancel();
        return;
      }
      try {
        final result = await fn01ReadCoils(
          startAddress: startAddress,
          count: count,
        );
        if (!controller.isClosed) controller.add(result);
      } catch (e) {
        if (!controller.isClosed) controller.addError(e);
      }
    });

    return controller.stream;
  }

  Stream<List<bool>> continuousReadDiscreteInputs({
    required int startAddress,
    required int count,
    Duration interval = const Duration(seconds: 1),
  }) {
    final controller = StreamController<List<bool>>();
    _activeStreams.add(controller);

    Timer.periodic(interval, (timer) async {
      if (controller.isClosed || _manualDisconnect) {
        timer.cancel();
        return;
      }
      try {
        final result = await fn02ReadDiscreteInputs(
          startAddress: startAddress,
          count: count,
        );
        if (!controller.isClosed) controller.add(result);
      } catch (e) {
        if (!controller.isClosed) controller.addError(e);
      }
    });

    return controller.stream;
  }

  Stream<List<int>> continuousReadHoldingRegisters({
    required int startAddress,
    required int quantity,
    Duration interval = const Duration(seconds: 1),
  }) {
    final controller = StreamController<List<int>>();
    _activeStreams.add(controller);

    Timer.periodic(interval, (timer) async {
      if (controller.isClosed || _manualDisconnect) {
        timer.cancel();
        return;
      }
      try {
        final result = await fn03ReadHoldingRegisters(
          startAddress: startAddress,
          quantity: quantity,
        );
        if (!controller.isClosed) controller.add(result);
      } catch (e) {
        if (!controller.isClosed) controller.addError(e);
      }
    });

    return controller.stream;
  }

  Stream<List<int>> continuousReadInputRegisters({
    required int startAddress,
    required int quantity,
    Duration interval = const Duration(seconds: 1),
  }) {
    final controller = StreamController<List<int>>();
    _activeStreams.add(controller);

    Timer.periodic(interval, (timer) async {
      if (controller.isClosed || _manualDisconnect) {
        timer.cancel();
        return;
      }
      try {
        final result = await fn04ReadInputRegisters(
          startAddress: startAddress,
          quantity: quantity,
        );
        if (!controller.isClosed) controller.add(result);
      } catch (e) {
        if (!controller.isClosed) controller.addError(e);
      }
    });

    return controller.stream;
  }

  Stream<bool> continuousWriteRegisters({
    required int startAddress,
    required List<int> values,
    Duration interval = const Duration(milliseconds: 100),
  }) {
    final controller = StreamController<bool>();

    _activeStreams.add(controller);

    Timer.periodic(interval, (timer) async {
      if (controller.isClosed || _manualDisconnect) {
        timer.cancel();
        return;
      }

      try {
        final result = await fn16WriteMultipleRegisters(
          startAddress: startAddress,
          values: values,
        );

        if (!controller.isClosed) {
          controller.add(result);
        }
      } catch (e) {
        if (!controller.isClosed) {
          controller.addError(e);
        }
      }
    });

    return controller.stream;
  }

}

class _PendingRequest {
  final Completer<List<int>> completer;
  final Timer timer;

  _PendingRequest(this.completer, this.timer);
}

class _AsyncLock {
  Future<void>? _current;

  Future<T> synchronized<T>(Future<T> Function() fn) async {
    while (_current != null) {
      await _current;
    }

    final completer = Completer<void>();
    _current = completer.future;

    try {
      return await fn();
    } finally {
      completer.complete();
      _current = null;
    }
  }
}
