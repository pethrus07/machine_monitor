import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';
import 'modbus_client_tcp.dart';

/// Mapa observável de endereço → valor com notificação na escrita.
///
/// Reproduz a sintaxe de acesso da IHM original (`ihm.LW[520] = 10`). A leitura
/// devolve o último valor conhecido; a escrita só dispara [onSet] (e notifica)
/// quando o valor realmente muda, evitando tráfego Modbus redundante.
class IHMMap {
  IHMMap({required this.onSet, int size = 1000}) {
    for (var i = 0; i <= size; i++) {
      _data[i] = 0;
    }
  }

  final Map<int, dynamic> _data = {};
  final void Function(int key, dynamic value) onSet;
  final ValueNotifier<int> _revision = ValueNotifier<int>(0);

  dynamic operator [](int key) => _data[key];

  void operator []=(int key, dynamic value) {
    if (_data[key] == value) return;
    _data[key] = value;
    onSet(key, value);
    _revision.value++;
  }

  /// Observe para reagir a qualquer alteração no mapa.
  ValueListenable<int> get revision => _revision;

  Iterable<int> get keys => _data.keys;
  bool containsKey(int key) => _data.containsKey(key);
  int get length => _data.length;

  void dispose() => _revision.dispose();
}

/// IHM Inovance — uma instância por máquina/equipamento.
///
/// Abre a conexão Modbus uma única vez e mantém leituras contínuas em segundo
/// plano (coils → [LB], holding registers → [LW]). As fontes de dados leem
/// direto desses mapas, sem reabrir socket a cada polling. Se a conexão cair,
/// o [ModbusClientTcp] reconecta sozinho na próxima requisição.
///
/// Uso:
/// ```dart
/// final ihm = IHMInovance();
/// await ihm.connect(host: '192.168.0.10', port: 502);
/// final status = ihm.LW[0];
/// await ihm.writeRegister(520, 1);
/// ```
class IHMInovance {
  IHMInovance() {
    // Os mapas Write_* propagam a escrita para o CLP; os de leitura apenas
    // guardam o que foi recebido (onSet vazio).
    Write_LW = IHMMap(onSet: _writeRegister);
    Write_LB = IHMMap(onSet: _writeCoil);
    LW = IHMMap(onSet: (_, __) {});
    LB = IHMMap(onSet: (_, __) {});
  }

  static final Logger _log = Logger('IHMInovance');

  late final ModbusClientTcp _modbus;
  bool _connected = false;
  String _label = '';

  // Mapas observáveis expostos às fontes de dados.
  // ignore: non_constant_identifier_names
  late final IHMMap LW; // Holding registers lidos (banco Inovance)
  // ignore: non_constant_identifier_names
  late final IHMMap LB; // Coils lidos (banco Inovance)
  // ignore: non_constant_identifier_names
  late final IHMMap Write_LW; // Escrita de registrador
  // ignore: non_constant_identifier_names
  late final IHMMap Write_LB; // Escrita de coil

  // Buffers brutos da última leitura contínua.
  List<bool> coils = [];
  List<int> holdingRegisters = [];

  bool get isConnected => _connected;

  // ── Conexão ──────────────────────────────────────────────────────────────────

  Future<void> connect({
    required String host,
    required int port,
    int unitId = 1,
  }) async {
    if (_connected) {
      _log.warning('IHM já conectada ($_label)');
      return;
    }

    _label = '$host:$port';
    try {
      _log.info('Iniciando conexão ($_label)');
      _modbus = ModbusClientTcp(
        unitId: unitId,
        responseTimeout: const Duration(seconds: 2),
        connectionTimeout: const Duration(seconds: 5),
        isLittleEndian: false,
      );
      await _modbus.connect(host: host, port: port);
      _connected = true;
      _log.info('IHM conectada ($_label)');
      _startContinuousReading();
    } catch (e) {
      _log.severe('Erro ao conectar ($_label): $e');
      _connected = false;
      rethrow;
    }
  }

  Future<void> disconnect() async {
    if (!_connected) return;
    await _modbus.disconnect();
    _connected = false;
    _log.info('Desconectada ($_label)');
  }

  // ── Leitura contínua ─────────────────────────────────────────────────────────

  void _startContinuousReading() {
    _modbus
        .continuousReadCoils(
          startAddress: 0,
          count: 1000,
          interval: const Duration(seconds: 5),
        )
        .listen((data) {
      coils = data;
      for (var i = 0; i < data.length; i++) {
        LB[i] = data[i];
      }
    }, onError: (Object e) => _log.warning('Falha lendo coils ($_label): $e'));

    _modbus
        .continuousReadHoldingRegisters(
          startAddress: 0,
          quantity: 125,
          interval: const Duration(seconds: 5),
        )
        .listen((data) {
      holdingRegisters = data;
      for (var i = 0; i < data.length; i++) {
        LW[i] = data[i];
      }
    }, onError: (Object e) => _log.warning('Falha lendo LW ($_label): $e'));

    _log.info('Leituras contínuas iniciadas ($_label)');
  }

  // ── Escrita (disparada pelos mapas Write_*) ──────────────────────────────────

  void _writeRegister(int address, dynamic value) {
    if (value is! int) return;
    _modbus
        .fn06WriteSingleRegister(address: address, value: value)
        .catchError((Object e) {
      _log.severe('Erro escrevendo LW[$address] ($_label): $e');
      return false;
    });
  }

  void _writeCoil(int address, dynamic value) {
    if (value is! bool) return;
    _modbus
        .fn05WriteSingleCoil(address: address, value: value)
        .catchError((Object e) {
      _log.severe('Erro escrevendo LB[$address] ($_label): $e');
      return false;
    });
  }

  // ── Acesso direto (aguarda confirmação do CLP) ───────────────────────────────

  Future<bool> writeRegister(int address, int value) {
    if (!_connected) throw StateError('IHM não conectada ($_label)');
    return _modbus.fn06WriteSingleRegister(address: address, value: value);
  }

  Future<bool> writeCoil(int address, bool value) {
    if (!_connected) throw StateError('IHM não conectada ($_label)');
    return _modbus.fn05WriteSingleCoil(address: address, value: value);
  }

  int holdingRegister(int index) =>
      (index >= 0 && index < holdingRegisters.length)
          ? holdingRegisters[index]
          : 0;

  bool coil(int index) =>
      (index >= 0 && index < coils.length) ? coils[index] : false;
}
