import 'modbus_client_tcp.dart';
import 'package:logging/logging.dart';
import 'package:flutter/foundation.dart';

/// Classe interna para interceptar acesso ao map COM NOTIFICAÇÃO
class IHMMap {
  final Map<int, dynamic> _data = {};
  final Function(int key, dynamic value) onSet;

  // ✅ ValueNotifier para notificar mudanças
  final ValueNotifier<int> _changeNotifier = ValueNotifier<int>(0);

  IHMMap({required this.onSet}) {
    // Inicializar com valores padrão
    for (int i = 0; i <= 1000; i++) {
      _data[i] = false; // bool
    }
    for (int i = 0; i <= 1000; i++) {
      _data[i] = 0; // int
    }
  }

  /// Getter - Acessar valor: LW[520]
  dynamic operator [](int key) {
    return _data[key];
  }

  /// Setter - Atribuir valor: LW[520] = true
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
class IHMInovance {

  static final IHMInovance _instance = IHMInovance._internal();
  static final Logger _logger = Logger('IHMInovance');

  late ModbusClientTcp _modbus;
  bool _isConnected = false;

  // ===== MAPS COM INTERCEPTAÇÃO E NOTIFICAÇÃO =====
  late final IHMMap LW;
  late final IHMMap LB;
  late final IHMMap Write_LW;
  late final IHMMap Write_LB;

  // Dados armazenados das 4 leituras
  List<bool> coils = [];
  List<bool> discreteInputs = [];
  List<int> holdingRegisters = [];
  List<int> inputRegisters = [];

  IHMInovance._internal() {
    // Inicializar maps com callbacks
    Write_LW = IHMMap(onSet: _handleWriteLWSet);
    Write_LB = IHMMap(onSet: _handleWriteLBSet);
    LW = IHMMap(onSet: _handleReadLWSet);
    LB = IHMMap(onSet: _handleReadLBSet);
  }

  /// Obter instância única
  static IHMInovance get instance => _instance;

  /// Atalho para usar sem .instance
  factory IHMInovance() {
    return _instance;
  }

  /// Callback quando for alterar algum parâmetro da IHM
  void _handleWriteLWSet(int key, dynamic value) {
    //_logger.info('📝 LW[$key] = $value');
    try {
       _modbus.fn06WriteSingleRegister(address: key, value: value);
      //print('📝 LW[$key] = $value');
    } catch (e) {
      print(e);
    }
  }

  /// Callback quando for alterar algum parâmetro da IHM
  void _handleWriteLBSet(int key, dynamic value) {
    //_logger.info('📝 LB[$key] = $value');
    try {
      _modbus.fn05WriteSingleCoil(address: key, value: value);
      //print('📝 LW[$key] = $value');
    } catch (e) {
      print(e);
    }
  }

  /// Callback quando for fazer leitura dos parâmetros da IHM
  void _handleReadLWSet(int key, dynamic value) {
    //_logger.info('📝 LW[$key] = $value');
    //print('📝 LB[$key] = $value');
  }

  /// Callback quando for fazer leitura dos parâmetros da IHM
  void _handleReadLBSet(int key, dynamic value) {
    //_logger.info('📝 LB[$key] = $value');
    //print('📝 LB[$key] = $value');
  }

  /// Conectar e iniciar leituras automáticas
  Future<void> connect({
    required String host,
    required int port,
    int unitId = 1,
  }) async {
    if (_isConnected) {
      _logger.warning('⚠️ IHM já conectada!');
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

      _logger.info('✅ IHM Inovance conectado: $host:$port');

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

  /// Iniciar leitura contínua da IHM
  void _startContinuousReading() {

    // Read LB
    _modbus
        .continuousReadCoils(
          startAddress: 0,
          count: 1000,
          interval: Duration(milliseconds: 5000),
        )
        .listen((data) {
          discreteInputs = data;

          // ✅ Atualizar LW[0-999] com entradas discretas
          for (int i = 0; i < data.length && i < 1000; i++) {
            LB[i] = data[i];
            if (data[i]) {
              print('LB ${i}: ${data[i]}');
            }
          }
        });

    // Read LW
    _modbus
        .continuousReadHoldingRegisters(
          startAddress: 0,
          quantity: 125,
          interval: Duration(milliseconds: 5000),
        )
        .listen((data) {
          holdingRegisters = data;

          print('Data Length: ${data.length}');

          // ✅ Atualizar LB[544-563] com holding registers
          for (int i = 0; i < data.length && i < 125; i++) {
            LW[i] = data[i];
            if (LW[i]!= 0) {
              print('LW ${i}: ${data[i]}');
            }
          }
        });

    _logger.info('✅ Leituras Contínuas iniciadas');
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
final IHM = IHMInovance();
