import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';

import '../../core/network/modbus_client_tcp.dart';
import '../../models/tex_data.dart';

/// Controlador de uma bancada TEX G4 via Modbus TCP/IP.
///
/// **Uma instância por equipamento** — cada bancada cadastrada tem o seu próprio
/// [TexG4], com socket e leitura contínua independentes. (A versão original era
/// um singleton global, o que impedia conectar em mais de uma bancada ao mesmo
/// tempo; agora cada IP roda isolado.)
///
/// Conecta, lê continuamente os holding registers, converte para [TexData] e
/// publica o último estado em [data]. Os comandos do operador (start/stop/BCD)
/// viram escrita de registrador único.
class TexG4 {
  TexG4({this.unitId = 1});

  static final Logger _logger = Logger('TexG4');

  final int unitId;

  ModbusClientTcp? _modbus;
  StreamSubscription<List<int>>? _readSub;
  bool _isConnected = false;

  /// Último estado convertido, observável pela camada de cima.
  final ValueNotifier<TexData> data = ValueNotifier<TexData>(TexData());

  /// Últimos registradores brutos lidos (útil para diagnóstico).
  List<int> holdingRegisters = const [];

  bool get isConnected => _isConnected;

  // ── Conexão ────────────────────────────────────────────────────────────────

  Future<void> connect({
    required String host,
    required int port,
    Duration interval = const Duration(milliseconds: 500),
  }) async {
    if (_isConnected) {
      _logger.warning('TEX $host:$port já conectado');
      return;
    }

    try {
      _logger.info('Conectando ao TEX $host:$port...');

      // Registradores brutos (sem byte-swap): a conversão de floats é feita em
      // [registersToTexData], que espera os words na ordem little-endian do CLP.
      final modbus = ModbusClientTcp(
        unitId: unitId,
        responseTimeout: const Duration(seconds: 2),
        connectionTimeout: const Duration(seconds: 5),
        isLittleEndian: false,
      );
      _modbus = modbus;

      await modbus.connect(host: host, port: port);
      _isConnected = true;
      _logger.info('Conectado em $host:$port');

      _startContinuousReading(interval);
    } catch (e) {
      _logger.severe('Erro ao conectar em $host:$port: $e');
      _isConnected = false;
      rethrow;
    }
  }

  Future<void> disconnect() async {
    if (!_isConnected) return;
    await _readSub?.cancel();
    _readSub = null;
    await _modbus?.disconnect();
    _isConnected = false;
    _logger.info('TEX desconectado');
  }

  // ── Leitura contínua ─────────────────────────────────────────────────────────

  void _startContinuousReading(Duration interval) {
    _readSub = _modbus!
        .continuousReadHoldingRegisters(
          startAddress: 0,
          quantity: kTexRegisterCount,
          interval: interval,
        )
        .listen(
      (registers) {
        if (registers.length < kTexRegisterCount) return;
        holdingRegisters = registers;
        try {
          data.value = registersToTexData(registers);
        } catch (e) {
          _logger.warning('Falha convertendo TEX: $e');
        }
      },
      onError: (Object e) => _logger.warning('Falha lendo TEX: $e'),
    );
    _logger.info('Leitura contínua iniciada');
  }

  // ── Comandos (escrita de registrador único) ─────────────────────────────────

  /// Inicia o teste: escreve 8 no registrador de controle (reg 0).
  ///
  /// TODO(tex): o registrador/bit de "bloqueio de escape" ainda não foi
  /// confirmado no CLP; por ora [blockExhaust] não altera o valor escrito.
  Future<bool> start({bool blockExhaust = false}) => _writeControl(8);

  /// Interrompe o teste: escreve 4 no registrador de controle (reg 0).
  Future<bool> stop() => _writeControl(4);

  /// Seleciona a câmara/lista de parâmetros via BCD (reg 2).
  Future<bool> setBCD(int value) {
    if (!_isConnected) throw StateError('TEX não conectado');
    return _modbus!.fn06WriteSingleRegister(address: 2, value: value);
  }

  Future<bool> _writeControl(int value) {
    if (!_isConnected) throw StateError('TEX não conectado');
    return _modbus!.fn06WriteSingleRegister(address: 0, value: value);
  }

  void dispose() {
    data.dispose();
  }
}
