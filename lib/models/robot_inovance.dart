import 'modbus_client_tcp.dart';
import 'package:logging/logging.dart';
import 'package:flutter/foundation.dart';

/// Classe interna para interceptar acesso ao map COM NOTIFICAÇÃO
class _RobotMap {
  final Map<int, dynamic> _data = {};
  final Function(int key, dynamic value) onSet;

  // ✅ ValueNotifier para notificar mudanças
  final ValueNotifier<int> _changeNotifier = ValueNotifier<int>(0);

  _RobotMap({required this.onSet}) {
    // Inicializar com valores padrão
    for (int i = 512; i <= 719; i++) {
      _data[i] = false; // bool
    }
    for (int i = 720; i <= 835; i++) {
      _data[i] = 0; // int
    }
  }

  /// Getter - Acessar valor: IN[520]
  dynamic operator [](int key) {
    return _data[key];
  }

  /// Setter - Atribuir valor: IN[520] = true
  void operator []=(int key, dynamic value) {
    if (_data[key] != value) {
      // Só notifica se realmente mudou
      _data[key] = value;
      onSet(key, value);

      // ✅ Notificar mudança (incrementa contador para forçar rebuild)
      _changeNotifier.value++;
    }
  }

  /// ✅ NOVO: Obter notifier para observar mudanças
  ValueNotifier<int> get changeNotifier => _changeNotifier;

  /// Obter todas as chaves
  Iterable<int> get keys => _data.keys;

  /// Obter todos os valores
  Iterable<dynamic> get values => _data.values;

  /// Conter chave?
  bool containsKey(int key) => _data.containsKey(key);

  /// Tamanho do map
  int get length => _data.length;
}

/// Robot Inovance - Singleton para comunicação com robô via Modbus
class RobotInovance {
  double axisX = 3.56;
  double axisY = 3.56;
  double axisZ = 3.56;

  static final RobotInovance _instance = RobotInovance._internal();
  static final Logger _logger = Logger('RobotInovance');

  late ModbusClientTcp _modbus;
  bool _isConnected = false;

  // ===== MAPS COM INTERCEPTAÇÃO E NOTIFICAÇÃO =====
  late final _RobotMap IN;
  late final _RobotMap OUT;

  // Dados armazenados das 4 leituras
  List<bool> coils = [];
  List<bool> discreteInputs = [];
  List<int> holdingRegisters = [];
  List<int> inputRegisters = [];

  RobotInovance._internal() {
    // Inicializar maps com callbacks
    IN = _RobotMap(onSet: _handleINSet);
    OUT = _RobotMap(onSet: _handleOUTSet);
  }

  /// Obter instância única
  static RobotInovance get instance => _instance;

  /// Atalho para usar sem .instance
  factory RobotInovance() {
    return _instance;
  }

  /// Callback quando alguém altera IN[chave]
  void _handleINSet(int key, dynamic value) {
    _logger.info('📝 IN[$key] = $value');
    try {
      _modbus.fn05WriteSingleCoil(address: 4096 + (key - 512), value: value);
      print('📝 IN[$key] = $value');
      print('📝 4096+(key-512) = $value');
    } catch (e) {
      print(e);
    }
  }

  /// Callback quando alguém altera OUT[chave]
  void _handleOUTSet(int key, dynamic value) {
    _logger.info('📝 OUT[$key] = $value');

    print('📝 OUT[$key] = $value');
    print('📝 4096+(key-512) = $value');

    // Executar ação específica baseada na chave
    _executeAction(key, value);
  }

  /// Executar ação customizada baseada na chave
  void _executeAction(int key, dynamic value) {
    _logger.fine('📍 Chave $key alterada para $value');
  }

  /// Conectar e iniciar leituras automáticas
  Future<void> connect({
    required String host,
    required int port,
    int unitId = 1,
  }) async {
    if (_isConnected) {
      _logger.warning('⚠️ Robô já conectado!');
      return;
    }

    try {
      _logger.info('Iniciando Conexão');

      // Criar cliente Modbus
      _modbus = ModbusClientTcp(
        unitId: unitId,
        responseTimeout: Duration(seconds: 2),
        connectionTimeout: Duration(seconds: 5),
      );

      // Conectar
      await _modbus.connect(host: host, port: port);
      _isConnected = true;

      _logger.info('✅ Robô Inovance conectado: $host:$port');

      // Iniciar as 4 leituras contínuas
      _startContinuousReading();
    } catch (e) {
      _logger.severe('❌ Erro ao conectar: $e');
      rethrow;
    }
  }

  /// Desconectar
  Future<void> disconnect() async {
    if (_isConnected) {
      await _modbus.disconnect();
      _isConnected = false;
      _logger.info('✅ Robô desconectado');
    }
  }

  /// Verificar conexão
  bool get isConnected => _isConnected;

  /// Iniciar as 4 leituras contínuas
  void _startContinuousReading() {
    _modbus
        .continuousReadDiscreteInputs(
          startAddress: 0,
          count: 208,
          interval: Duration(milliseconds: 200),
        )
        .listen((data) {
          coils = data;

          // ✅ Atualizar IN[512-527] com os valores das bobinas
          for (int i = 0; i < data.length && i < 208; i++) {
            OUT[512 + i] = data[i];
            if (data[i]) {
              // print('OUT ${512 + i}: ${data[i]}');
            }
          }

          _logger.fine('📍 IN[512]: $coils');
        });

    // Leitura 2:
    _modbus
        .continuousReadCoils(
          startAddress: 0,
          count: 26,
          interval: Duration(milliseconds: 200),
        )
        .listen((data) {
          discreteInputs = data;

          // ✅ Atualizar IN[528-635] com entradas discretas
          for (int i = 0; i < data.length && i < 26; i++) {
            IN[512 + i] = data[i];
            if (data[i]) {
              // print('IN ${512 + i}: ${data[i]}');
            }
          }

          _logger.fine('📍 OUT[512]: $discreteInputs');
        });

    // Leitura 3: Holding Registers (FC 03)
    _modbus
        .continuousReadHoldingRegisters(
          startAddress: 0,
          quantity: 26,
          interval: Duration(milliseconds: 3000),
        )
        .listen((data) {
          holdingRegisters = data;

          // ✅ Atualizar OUT[544-563] com holding registers
          for (int i = 0; i < data.length && i < 26; i++) {
            OUT[720 + i] = data[i];
            if (data[i] != 0) {
              // print('HR ${720 + i}: ${data[i]}');
            }
          }

          _logger.fine('📍 IN[720]: $holdingRegisters');
        });

    // Leitura 4: Input Registers (FC 04)
    _modbus
        .continuousReadInputRegisters(
          startAddress: 0,
          quantity: 20,
          interval: Duration(milliseconds: 3000),
        )
        .listen((data) {
          inputRegisters = data;

          // ✅ Atualizar IN[720-739] com input registers
          for (int i = 0; i < data.length && i < 20; i++) {
            IN[720 + i] = data[i];
            if (data[i] != 0) {
              // print('IR ${720 + i}: ${data[i]}');
            }
          }

          _logger.fine('📍 OUT[720]: $inputRegisters');
        });

    _logger.info('✅ 4 leituras contínuas iniciadas');
  }

  // ===== MÉTODOS AUXILIARES SIMPLIFICADOS =====

  /// Escrever uma bobina
  Future<bool> writeCoil(int address, bool value) async {
    if (!_isConnected) throw Exception('Robô não conectado');
    return await _modbus.fn05WriteSingleCoil(address: address, value: value);
  }

  /// Escrever um registrador
  Future<bool> writeRegister(int address, int value) async {
    if (!_isConnected) throw Exception('Robô não conectado');
    return await _modbus.fn06WriteSingleRegister(
      address: address,
      value: value,
    );
  }

  /// Obter valor de uma bobina (pelo índice)
  bool getCoil(int index) {
    if (index < 0 || index >= coils.length) return false;
    return coils[index];
  }

  /// Obter valor de entrada discreta (pelo índice)
  bool getDiscreteInput(int index) {
    if (index < 0 || index >= discreteInputs.length) return false;
    return discreteInputs[index];
  }

  /// Obter valor de registrador de retenção (pelo índice)
  int getHoldingRegister(int index) {
    if (index < 0 || index >= holdingRegisters.length) return 0;
    return holdingRegisters[index];
  }

  /// Obter valor de registrador de entrada (pelo índice)
  int getInputRegister(int index) {
    if (index < 0 || index >= inputRegisters.length) return 0;
    return inputRegisters[index];
  }
}

// ===== ALIAS GLOBAL =====
/// Acesso global simplificado
final Robot = RobotInovance();
