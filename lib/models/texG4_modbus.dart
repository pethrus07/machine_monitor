import 'dart:ffi';

import 'modbus_client_tcp.dart';
import 'package:logging/logging.dart';
import 'dart:typed_data';

/// =====================================================
///
/// Estrutura de dados do equipamento TEX
///
/// Contém todos os parâmetros convertidos do Modbus
///
/// =====================================================
class TexData {
  int control = 0;
  int digitalOutputs = 0;
  int bcd = 0;
  int outputPlus = 0;

  int timeElapsed = 0;

  double pressure = 0;
  double leak = 0;

  int pressureUnit = 0;
  int leakUnit = 0;

  int valveDiagnostic = 0;
  int ioDiagnostic = 0;

  int controlMirror = 0;

  int testStatus = 0;

  int currentChamber = 0;

  int currentParameterList = 0;

  String lot = '';

  double differentialPressure = 0;

  double returnPressure = 0;

  int returnPressureUnit = 0;
}

TexData registersToTexData(List<int> regs) {
  if (regs.length < 35) {
    throw Exception('Esperado no mínimo 35 registradores');
  }

  final d = TexData();

  // ==========================================
  // 0-3
  // ==========================================

  d.control = regs[0];
  d.digitalOutputs = regs[1];
  d.bcd = regs[2];
  d.outputPlus = regs[3];

  // ==========================================
  // 4-5
  // Tempo de Teste (INT32)
  // ==========================================

  d.timeElapsed = (regs[5] << 16) | regs[4];

  // ==========================================
  // 9-10
  // Pressão de Teste (FLOAT)
  // ==========================================

  final pressureBytes = ByteData(4);

  pressureBytes.setUint16(0, regs[9], Endian.little);

  pressureBytes.setUint16(2, regs[10], Endian.little);

  d.pressure = pressureBytes.getFloat32(0, Endian.little);

  // ==========================================
  // 11-12
  // Vazamento / Vazão
  // ==========================================

  final leakBytes = ByteData(4);

  leakBytes.setUint16(0, regs[11], Endian.little);

  leakBytes.setUint16(2, regs[12], Endian.little);

  d.leak = leakBytes.getFloat32(0, Endian.little);

  // ==========================================
  // 13-20
  // ==========================================

  d.pressureUnit = regs[13];

  d.leakUnit = regs[14];

  d.valveDiagnostic = regs[15];

  d.ioDiagnostic = regs[16];

  d.controlMirror = regs[17];

  d.testStatus = regs[18];

  d.currentChamber = regs[19];

  d.currentParameterList = regs[20];

  // ==========================================
  // 23-28
  // Lote (6 caracteres)
  // ==========================================

  d.lot = String.fromCharCodes([
    regs[23] & 0xFF,
    regs[24] & 0xFF,
    regs[25] & 0xFF,
    regs[26] & 0xFF,
    regs[27] & 0xFF,
    regs[28] & 0xFF,
  ]);

  // ==========================================
  // 29-30
  // Pressão Diferencial
  // ==========================================

  final diffBytes = ByteData(4);

  diffBytes.setUint16(0, regs[29], Endian.little);

  diffBytes.setUint16(2, regs[30], Endian.little);

  d.differentialPressure = diffBytes.getFloat32(0, Endian.little);

  // ==========================================
  // 31-32
  // Pressão Retorno
  // ==========================================

  final returnBytes = ByteData(4);

  returnBytes.setUint16(0, regs[31], Endian.little);

  returnBytes.setUint16(2, regs[32], Endian.little);

  d.returnPressure = returnBytes.getFloat32(0, Endian.little);

  // ==========================================
  // 33
  // Unidade pressão retorno
  // ==========================================

  d.returnPressureUnit = regs[33];

  return d;
}

/// =====================================================
///
/// Biblioteca TEX G4
///
/// Responsável por:
///
/// - Conectar via Modbus TCP
/// - Ler continuamente os registradores
/// - Converter para TexData
/// - Disponibilizar o último estado lido
///
/// =====================================================
class TexG4 {
  /// Instância Singleton
  static final TexG4 _instance = TexG4._internal();

  /// Logger
  static final Logger _logger = Logger('TexG4');

  /// Cliente Modbus TCP
  late ModbusClientTcp _modbus;

  /// Estado da conexão
  bool _isConnected = false;

  /// Últimos registradores lidos
  List<int> holdingRegisters = [];

  /// Último estado convertido
  TexData texData = TexData();

  /// Construtor privado
  TexG4._internal();

  /// Retorna instância única
  static TexG4 get instance => _instance;

  /// Factory Singleton
  factory TexG4() {
    return _instance;
  }

  /// =====================================================
  ///
  /// Conectar ao equipamento TEX
  ///
  /// =====================================================
  Future<void> connect({
    required String host,
    required int port,
    int unitId = 1,
  }) async {
    _logger.info('Entrando em conexão...');
    if (_isConnected) {
      _logger.warning('Equipamento já conectado');
      return;
    }

    try {
      _logger.info('Conectando ao TEX...');

      // Criar cliente Modbus
      _modbus = ModbusClientTcp(
        unitId: unitId,
        responseTimeout: const Duration(seconds: 2),
        connectionTimeout: const Duration(seconds: 5),
      );

      // Abrir conexão TCP
      await _modbus.connect(host: host, port: port);

      _isConnected = true;

      _logger.info('Conectado em $host:$port');

      // Iniciar leitura contínua
      _startContinuousReading();
    } catch (e) {
      _logger.severe('Erro ao conectar: $e');

      rethrow;
    }
  }

  /// =====================================================
  ///
  /// Desconectar do equipamento
  ///
  /// =====================================================
  Future<void> disconnect() async {
    if (!_isConnected) {
      return;
    }

    await _modbus.disconnect();

    _isConnected = false;

    _logger.info('TEX desconectado');
  }

  /// =====================================================
  ///
  /// Retorna status da conexão
  ///
  /// =====================================================
  bool get isConnected => _isConnected;

  /// =====================================================
  ///
  /// Inicia leitura contínua
  ///
  /// Lê:
  ///
  /// Registradores 0 até 21
  ///
  /// Total:
  /// 22 registradores
  ///
  /// =====================================================
  void _startContinuousReading() {
    _modbus
        .continuousReadHoldingRegisters(
          // Primeiro registrador
          startAddress: 0,

          // Quantidade total
          quantity: 35,

          // Tempo entre leituras
          interval: const Duration(milliseconds: 500),
        )
        .listen((registers) {
          // Salvar registradores recebidos
          holdingRegisters = registers;

          print('');
          print('========================================');
          print('REGISTRADORES RECEBIDOS');
          print('========================================');

          for (int i = 0; i < registers.length; i++) {
            print('Reg[$i] = ${registers[i]}');
          }

          try {
            // Converter para estrutura TEX
            texData = registersToTexData(registers);

            print('');
            print('========================================');
            print('TEX DATA');
            print('========================================');

            print('CONTROL: ${texData.control}');
            print('DIGITAL OUTPUTS: ${texData.digitalOutputs}');
            print('BCD: ${texData.bcd}');
            print('OUTPUT PLUS: ${texData.outputPlus}');
            print('TIME ELAPSED: ${texData.timeElapsed}');
            print('PRESSURE: ${texData.pressure}');
            print('LEAK: ${texData.leak}');
            print('PRESSURE UNIT: ${texData.pressureUnit}');
            print('LEAK UNIT: ${texData.leakUnit}');
            print('VALVE DIAGNOSTIC: ${texData.valveDiagnostic}');
            print('IO DIAGNOSTIC: ${texData.ioDiagnostic}');
            print('CONTROL MIRROR: ${texData.controlMirror}');
            print('TEST STATUS: ${texData.testStatus}');
            print('CURRENT CHAMBER: ${texData.currentChamber}');
            print('CURRENT PARAMETER LIST: ${texData.currentParameterList}');
            print('LOT: ${texData.lot}');
            print('DIFFERENTIAL PRESSURE: ${texData.differentialPressure}');
            print('RETURN PRESSURE: ${texData.returnPressure}');
            print('RETURN PRESSURE UNIT: ${texData.returnPressureUnit}');
          } catch (e) {
            print('Erro convertendo TEX: $e');
          }
        });

    _logger.info('Leitura contínua iniciada');
  }

  /// Escrever um registrador
  Future<bool> setBCD(int bcd) async {
    if (!_isConnected) throw Exception('Tex não conectado');
    return await _modbus.fn06WriteSingleRegister(
      address: 2,
      value: bcd,
    );
  }

  /// Escrever um registrador
  Future<bool> start(bool blockExhaust) async {
    if (!_isConnected) throw Exception('Tex não conectado');
    return await _modbus.fn06WriteSingleRegister(
      address: 0,
      value: 8,
    );
  }

  /// Escrever um registrador
  Future<bool> stop(bool blockExhaust) async {
    if (!_isConnected) throw Exception('Tex não conectado');
    return await _modbus.fn06WriteSingleRegister(
      address: 0,
      value: 4,
    );
  }


}

/// =====================================================
///
/// Alias global
///
/// Exemplo:
///
/// await TEX.connect(...)
///
/// print(TEX.texData.pressure)
///
/// =====================================================
final TEX = TexG4();
