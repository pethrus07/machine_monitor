import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import '../../models/models.dart';
import '../../models/tex_models.dart';
import '../data_sources.dart';
import 'tex_register_map.dart';

/// Fonte simulada da bancada TEX (Fase 1).
///
/// Cada [connect] cria uma sessão independente que roda o ciclo de teste em um
/// timer e publica [TexSnapshot]s. Substitui o antigo `SimulatorService`
/// baseado em Provider, mantendo a mesma física de simulação, mas encaixado na
/// arquitetura de fontes de dados do app.
class SimulatedTexDataSource implements TexDataSource {
  SimulatedTexDataSource({this.tick = const Duration(milliseconds: 100)});

  final Duration tick;

  @override
  TexSession connect(Machine machine) =>
      _SimulatedTexSession(machineName: machine.nome, tick: tick);
}

class _SimulatedTexSession implements TexSession {
  _SimulatedTexSession({required this.machineName, required this.tick}) {
    _snapshot = ValueNotifier<TexSnapshot>(_build());
    _timer = Timer.periodic(tick, (_) => _onTick());
  }

  final String machineName;
  final Duration tick;
  final Random _rng = Random();

  late final ValueNotifier<TexSnapshot> _snapshot;
  Timer? _timer;
  Timer? _restartTimer;

  // Estado interno do ciclo.
  TexPhase _phase = TexPhase.parado;
  TexResult _result = TexResult.nenhum;
  double _phaseElapsed = 0;
  double _pressao = 0;
  double _vazamento = 0;
  double _progresso = 0;
  bool _running = false;
  bool _bloqueado = false;
  int _bcd = 0;
  static const int _camera = 1;
  static const int _totalCameras = 1;

  late List<TexIoPin> _inputs = _initInputs();
  late List<TexIoPin> _outputs = _initOutputs();
  late final List<TexDiagnostic> _autoCheck = _initAutoCheck();
  late final List<TexDiagnostic> _diagnostico = _initDiagnostico();

  @override
  ValueListenable<TexSnapshot> get snapshot => _snapshot;

  // ── Comandos ─────────────────────────────────────────────────────────────────

  @override
  void start() {
    if (_bloqueado) return;
    _running = true;
    _phase = TexPhase.enchimento;
    _phaseElapsed = 0;
    _result = TexResult.nenhum;
    _publish();
  }

  @override
  void stop() {
    _restartTimer?.cancel();
    _running = false;
    _phase = TexPhase.parado;
    _phaseElapsed = 0;
    _pressao = 0;
    _vazamento = 0;
    _progresso = 0;
    _publish();
  }

  @override
  void toggleEscapeBlock() {
    _bloqueado = !_bloqueado;
    if (_bloqueado && _running) {
      stop();
    } else {
      _publish();
    }
  }

  @override
  void setBcd(int value) {
    _bcd = value;
    _publish();
  }

  // ── Loop de simulação ────────────────────────────────────────────────────────

  void _onTick() {
    if (!_running || _bloqueado) return;

    final dt = tick.inMilliseconds / 1000.0;
    _phaseElapsed += dt;
    final duration = _phase.defaultDuration;

    _simulatePhysics();

    // Falha de diagnóstico muito rara, proporcional ao tick.
    if (_rng.nextInt((5 / dt).round().clamp(1, 1000)) == 0) {
      _toggleRandomDiagnostic();
    }
    _updateIo();

    if (_phaseElapsed >= duration && _phase != TexPhase.parado) {
      _advancePhase();
    }
    _publish();
  }

  void _simulatePhysics() {
    final duration = _phase.defaultDuration;
    final t = duration == 0 ? 0.0 : (_phaseElapsed / duration).clamp(0.0, 1.0);

    switch (_phase) {
      case TexPhase.enchimento:
        _pressao = 0.999 * t + _rng.nextDouble() * 0.005;
        _vazamento = 0;
        _progresso = t * 0.2;
        break;
      case TexPhase.equalizacao:
        _pressao = 0.999 + (_rng.nextDouble() - 0.5) * 0.002;
        _vazamento = 0;
        _progresso = 0.2 + t * 0.15;
        break;
      case TexPhase.estabilizacao:
        _pressao = 0.999 + (_rng.nextDouble() - 0.5) * 0.001;
        _vazamento = _rng.nextDouble() * 0.02;
        _progresso = 0.35 + t * 0.15;
        break;
      case TexPhase.medicao:
        _pressao = 0.999 - _rng.nextDouble() * 0.003;
        _vazamento = 0.001 + _rng.nextDouble() * 0.015;
        _progresso = 0.5 + t * 0.35;
        break;
      case TexPhase.escape:
        _pressao = 0.999 * (1 - t) + _rng.nextDouble() * 0.01;
        _vazamento = 0;
        _progresso = 0.85 + t * 0.15;
        break;
      case TexPhase.resultado:
        _pressao = 0;
        _vazamento = 0;
        _progresso = 1.0;
        break;
      case TexPhase.parado:
        _pressao = 0;
        _vazamento = 0;
        _progresso = 0;
        break;
    }

    _pressao = _pressao.clamp(0.0, 2.0);
    _vazamento = _vazamento.clamp(0.0, 1.0);
    _progresso = _progresso.clamp(0.0, 1.0);
  }

  void _advancePhase() {
    const cycle = TexPhaseMeta.cycle;
    final idx = cycle.indexOf(_phase);
    if (idx < 0 || idx >= cycle.length - 1) return;

    _phase = cycle[idx + 1];
    _phaseElapsed = 0;

    if (_phase == TexPhase.resultado) {
      // 85% de aprovação.
      _result = _rng.nextDouble() < 0.85 ? TexResult.aprovado : TexResult.reprovado;

      // Reinicia o ciclo automaticamente após exibir o resultado.
      _restartTimer?.cancel();
      _restartTimer = Timer(const Duration(seconds: 2), () {
        if (_running) {
          _phase = TexPhase.enchimento;
          _phaseElapsed = 0;
          _publish();
        }
      });
    }
  }

  // ── E-S e diagnósticos ───────────────────────────────────────────────────────

  void _updateIo() {
    _inputs = _inputs.map((pin) {
      bool active;
      switch (pin.number) {
        case 4: // INÍCIO
          active =
              _running && _phase == TexPhase.enchimento && _phaseElapsed < 0.5;
          break;
        case 3: // PARADA
          active = !_running;
          break;
        case 8: // BLOQUEIA ESCAPE
          active = _bloqueado;
          break;
        default:
          active = _rng.nextInt(80) == 0 ? !pin.active : pin.active;
      }
      return pin.copyWith(active: active);
    }).toList();

    _outputs = _outputs.map((pin) {
      bool active;
      switch (pin.number) {
        case 2: // APROVA
          active =
              _result == TexResult.aprovado && _phase == TexPhase.resultado;
          break;
        case 3: // REPROVA TESTE
          active =
              _result == TexResult.reprovado && _phase == TexPhase.resultado;
          break;
        case 7: // ESCAPE EXTERNO
          active = _phase == TexPhase.escape;
          break;
        case 8: // BUSY
          active = _running &&
              _phase != TexPhase.parado &&
              _phase != TexPhase.resultado;
          break;
        default:
          active = _rng.nextInt(100) == 0 ? !pin.active : pin.active;
      }
      return pin.copyWith(active: active);
    }).toList();
  }

  void _toggleRandomDiagnostic() {
    if (_rng.nextBool()) {
      final i = _rng.nextInt(_autoCheck.length);
      _autoCheck[i] = _autoCheck[i].copyWith(hasError: !_autoCheck[i].hasError);
    } else {
      final i = _rng.nextInt(_diagnostico.length);
      _diagnostico[i] =
          _diagnostico[i].copyWith(hasError: !_diagnostico[i].hasError);
    }
  }

  // ── Publicação do snapshot ───────────────────────────────────────────────────

  void _publish() => _snapshot.value = _build();

  TexSnapshot _build() => TexSnapshot(
        programName: '#PRG BCD $_bcd',
        cameraNumber: _camera,
        totalCameras: _totalCameras,
        phase: _phase,
        result: _result,
        elapsedTime: _phaseElapsed,
        pressao: _pressao,
        vazamento: _vazamento,
        progresso: _progresso,
        running: _running,
        escapeBloqueado: _bloqueado,
        inputs: _inputs,
        outputs: _outputs,
        autoCheck: _autoCheck,
        diagnostico: _diagnostico,
      );

  // ── Estado inicial das listas ────────────────────────────────────────────────

  List<TexIoPin> _initInputs() => List.generate(
        TexRegisterMap.inputLabels.length,
        (i) => TexIoPin(number: i + 1, label: TexRegisterMap.inputLabels[i]),
      );

  List<TexIoPin> _initOutputs() => List.generate(
        TexRegisterMap.outputLabels.length,
        (i) => TexIoPin(number: i + 1, label: TexRegisterMap.outputLabels[i]),
      );

  List<TexDiagnostic> _initAutoCheck() => [
        for (final label in TexRegisterMap.autoCheckLabels)
          TexDiagnostic(label: label),
      ];

  List<TexDiagnostic> _initDiagnostico() => [
        for (final label in TexRegisterMap.diagnosticoLabels)
          TexDiagnostic(label: label),
      ];

  @override
  Future<void> dispose() async {
    _timer?.cancel();
    _restartTimer?.cancel();
    _snapshot.dispose();
  }
}
