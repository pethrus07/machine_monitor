import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';
import '../../models/models.dart';
import '../../models/tex_data.dart';
import '../../models/tex_models.dart';
import '../data_sources.dart';
import 'tex_g4.dart';
import 'tex_register_map.dart';

/// Fonte real da bancada TEX via Modbus TCP/IP.
///
/// Cada chamada de [connect] cria uma sessão com o seu **próprio** [TexG4]
/// conectado ao IP daquela máquina — duas bancadas (TEX 1, TEX 2, …) rodam em
/// instâncias totalmente isoladas, sem estado compartilhado. A sessão lê o
/// [TexData] cru continuamente e o traduz em [TexSnapshot] para a tela.
class ModbusTexDataSource implements TexDataSource {
  ModbusTexDataSource({
    this.port = 502,
    this.unitId = 1,
    this.refresh = const Duration(milliseconds: 500),
  });

  final int port;
  final int unitId;
  final Duration refresh;

  @override
  TexSession connect(Machine machine) => _ModbusTexSession(
        machine: machine,
        port: port,
        unitId: unitId,
        refresh: refresh,
      );
}

class _ModbusTexSession implements TexSession {
  _ModbusTexSession({
    required this.machine,
    required this.port,
    required this.unitId,
    required this.refresh,
  }) {
    _snapshot = ValueNotifier<TexSnapshot>(const TexSnapshot());
    _tex = TexG4(unitId: unitId);
    _tex.data.addListener(_onData);
    _connect();
  }

  static final Logger _log = Logger('ModbusTexSession');

  final Machine machine;
  final int port;
  final int unitId;
  final Duration refresh;

  late final TexG4 _tex;
  late final ValueNotifier<TexSnapshot> _snapshot;

  /// Estado de bloqueio de escape — mantido localmente até o registrador
  /// correspondente do CLP ser confirmado (ver TODO em [TexG4.start]).
  bool _escapeBloqueado = false;

  @override
  ValueListenable<TexSnapshot> get snapshot => _snapshot;

  Future<void> _connect() async {
    try {
      await _tex.connect(host: machine.ip, port: port, interval: refresh);
    } catch (e) {
      _log.severe('TEX ${machine.ip}: falha ao conectar → $e');
      _snapshot.value =
          _snapshot.value.copyWith(alarme: 'SEM COMUNICAÇÃO COM A BANCADA');
    }
  }

  /// Traduz o último [TexData] cru no [TexSnapshot] consumido pela UI.
  void _onData() {
    final d = _tex.data.value;
    final running = TexRegisterMap.runningFrom(d.digitalOutputs, d.testStatus);

    _snapshot.value = TexSnapshot(
      programName: '#PRG ${d.currentParameterList}',
      cameraNumber: d.currentChamber < 1 ? 1 : d.currentChamber,
      totalCameras: d.currentChamber < 1 ? 1 : d.currentChamber,
      phase: TexRegisterMap.phaseFromStatus(d.testStatus),
      result: TexRegisterMap.resultFromOutputs(d.digitalOutputs),
      elapsedTime: d.timeElapsed / 10.0,
      pressao: d.pressure,
      vazamento: d.leak,
      progresso: 0.0,
      running: running,
      escapeBloqueado: _escapeBloqueado,
      outputs: TexRegisterMap.pinsFromBits(
          TexRegisterMap.outputLabels, d.digitalOutputs),
      autoCheck: TexRegisterMap.diagsFromBits(
          TexRegisterMap.autoCheckLabels, d.valveDiagnostic),
      diagnostico: TexRegisterMap.diagsFromBits(
          TexRegisterMap.diagnosticoLabels, d.ioDiagnostic),
      alarme: '',
    );
  }

  // ── Comandos do operador ─────────────────────────────────────────────────────

  @override
  void start() => _guard(() => _tex.start(blockExhaust: _escapeBloqueado));

  @override
  void stop() => _guard(_tex.stop);

  @override
  void toggleEscapeBlock() {
    _escapeBloqueado = !_escapeBloqueado;
    // Reflete imediatamente na UI mesmo antes do próximo ciclo de leitura.
    _snapshot.value = _snapshot.value.copyWith(escapeBloqueado: _escapeBloqueado);
  }

  /// Navegação de câmara = troca do BCD selecionado no CLP.
  @override
  void nextCamera() {
    final atual = _tex.data.value.currentChamber;
    _guard(() => _tex.setBCD(atual + 1));
  }

  @override
  void prevCamera() {
    final atual = _tex.data.value.currentChamber;
    if (atual <= 1) return;
    _guard(() => _tex.setBCD(atual - 1));
  }

  /// Executa um comando de escrita ignorando falhas pontuais de rede (a leitura
  /// contínua já sinaliza perda de comunicação por outro caminho).
  void _guard(Future<bool> Function() action) {
    if (!_tex.isConnected) return;
    action().catchError((Object e) {
      _log.warning('TEX ${machine.ip}: comando falhou → $e');
      return false;
    });
  }

  @override
  Future<void> dispose() async {
    _tex.data.removeListener(_onData);
    await _tex.disconnect();
    _tex.dispose();
    _snapshot.dispose();
  }
}
