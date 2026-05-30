import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';
import '../../core/network/ihm_inovance.dart';
import '../../models/models.dart';
import '../../models/tex_models.dart';
import '../data_sources.dart';
import 'tex_register_map.dart';

/// Fonte real da bancada TEX (Fase 2) via Modbus TCP/IP.
///
/// Reaproveita exatamente a mesma pilha de rede do monitor ([IHMInovance] →
/// [ModbusClientTcp]). A sessão conecta, lê os mapas LW/LB segundo o
/// [TexRegisterMap] e reconstrói um [TexSnapshot] na cadência configurada; os
/// comandos do operador viram escrita de coils.
class ModbusTexDataSource implements TexDataSource {
  ModbusTexDataSource({
    this.port = 502,
    this.unitId = 1,
    this.refresh = const Duration(milliseconds: 200),
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
    _connect();
  }

  static final Logger _log = Logger('ModbusTexSession');

  final Machine machine;
  final int port;
  final int unitId;
  final Duration refresh;

  final IHMInovance _ihm = IHMInovance();
  late final ValueNotifier<TexSnapshot> _snapshot;
  Timer? _timer;

  @override
  ValueListenable<TexSnapshot> get snapshot => _snapshot;

  Future<void> _connect() async {
    try {
      await _ihm.connect(host: machine.ip, port: port, unitId: unitId);
      _timer = Timer.periodic(refresh, (_) => _rebuild());
    } catch (e) {
      _log.severe('TEX ${machine.ip}: falha ao conectar → $e');
      _snapshot.value =
          _snapshot.value.copyWith(alarme: 'SEM COMUNICAÇÃO COM A BANCADA');
    }
  }

  /// Lê os mapas da IHM e publica um novo snapshot.
  void _rebuild() {
    int lw(int i) => _ihm.LW[i] is int ? _ihm.LW[i] as int : 0;
    bool lb(int i) => _ihm.LB[i] == true;

    final phase = TexRegisterMap.phaseFromCode(lw(TexRegisterMap.lwPhase));
    final result =
        TexRegisterMap.resultFromCode(lw(TexRegisterMap.lwResultado));

    _snapshot.value = TexSnapshot(
      programName: '#PRG TESTE',
      cameraNumber: lw(TexRegisterMap.lwCamaraAtual).clamp(1, 999),
      totalCameras: lw(TexRegisterMap.lwCamaraTotal).clamp(1, 999),
      phase: phase,
      result: result,
      elapsedTime: lw(TexRegisterMap.lwElapsed) / 10.0,
      pressao: lw(TexRegisterMap.lwPressao) / 1000.0,
      vazamento: lw(TexRegisterMap.lwVazamento) / 1000.0,
      progresso: (lw(TexRegisterMap.lwProgresso) / 100.0).clamp(0.0, 1.0),
      running: phase != TexPhase.parado,
      escapeBloqueado: lb(TexRegisterMap.coilBlockEscape),
      inputs: TexRegisterMap.pinsFrom(
          TexRegisterMap.inputLabels, lb, TexRegisterMap.coilInputsBase),
      outputs: TexRegisterMap.pinsFrom(
          TexRegisterMap.outputLabels, lb, TexRegisterMap.coilOutputsBase),
      autoCheck: TexRegisterMap.diagsFrom(
          TexRegisterMap.autoCheckLabels, lb, TexRegisterMap.coilAutoCheckBase),
      diagnostico: TexRegisterMap.diagsFrom(TexRegisterMap.diagnosticoLabels,
          lb, TexRegisterMap.coilDiagnosticoBase),
    );
  }

  // ── Comandos → escrita de coils ──────────────────────────────────────────────

  @override
  void start() => _pulse(TexRegisterMap.coilStart);

  @override
  void stop() => _pulse(TexRegisterMap.coilStop);

  @override
  void toggleEscapeBlock() {
    final novo = !_snapshot.value.escapeBloqueado;
    _ihm.Write_LB[TexRegisterMap.coilBlockEscape] = novo;
  }

  @override
  void nextCamera() => _pulse(TexRegisterMap.coilNextCamera);

  @override
  void prevCamera() => _pulse(TexRegisterMap.coilPrevCamera);

  /// Botões do CLP são acionados por pulso: liga e desliga a coil em seguida.
  void _pulse(int coil) {
    _ihm.Write_LB[coil] = true;
    Future<void>.delayed(const Duration(milliseconds: 120), () {
      _ihm.Write_LB[coil] = false;
    });
  }

  @override
  Future<void> dispose() async {
    _timer?.cancel();
    await _ihm.disconnect();
    _snapshot.dispose();
  }
}
