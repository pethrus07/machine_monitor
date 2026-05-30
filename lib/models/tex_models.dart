import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';

/// Modelos da bancada de teste de estanqueidade TEX "Anel Hídrico".
///
/// O ciclo de teste passa por fases ([TexPhase]) e termina com um resultado
/// ([TexResult]). Um [TexSnapshot] é uma fotografia imutável de tudo que a
/// interface precisa exibir em um dado instante — produzida pela
/// [TexDataSource] e consumida pela [TexConsoleScreen].

// ─── Fases do ciclo ───────────────────────────────────────────────────────────

enum TexPhase {
  parado,
  enchimento,
  equalizacao,
  estabilizacao,
  medicao,
  escape,
  resultado,
}

extension TexPhaseMeta on TexPhase {
  String get displayName {
    switch (this) {
      case TexPhase.parado:
        return 'PARADO';
      case TexPhase.enchimento:
        return 'ENCHENDO';
      case TexPhase.equalizacao:
        return 'EQUALIZANDO';
      case TexPhase.estabilizacao:
        return 'ESTABILIZANDO';
      case TexPhase.medicao:
        return 'AVALIANDO';
      case TexPhase.escape:
        return 'ESCAPANDO';
      case TexPhase.resultado:
        return 'RESULTADO';
    }
  }

  /// Duração padrão da fase no modo simulado, em segundos.
  /// No modo real quem dita a duração é o próprio CLP.
  double get defaultDuration {
    switch (this) {
      case TexPhase.parado:
        return 0;
      case TexPhase.enchimento:
        return 3.0;
      case TexPhase.equalizacao:
        return 2.0;
      case TexPhase.estabilizacao:
        return 2.5;
      case TexPhase.medicao:
        return 5.0;
      case TexPhase.escape:
        return 2.0;
      case TexPhase.resultado:
        return 2.0;
    }
  }

  /// Sequência de fases de um ciclo completo (sem o estado "parado").
  static const List<TexPhase> cycle = [
    TexPhase.enchimento,
    TexPhase.equalizacao,
    TexPhase.estabilizacao,
    TexPhase.medicao,
    TexPhase.escape,
    TexPhase.resultado,
  ];
}

// ─── Resultado do teste ───────────────────────────────────────────────────────

enum TexResult { nenhum, aprovado, reprovado }

extension TexResultMeta on TexResult {
  String get label {
    switch (this) {
      case TexResult.nenhum:
        return '';
      case TexResult.aprovado:
        return 'APROVADO';
      case TexResult.reprovado:
        return 'REPROVADO';
    }
  }
}

// ─── Entradas e saídas digitais ───────────────────────────────────────────────

class TexIoPin {
  final int number;
  final String label;
  final bool active;

  const TexIoPin({
    required this.number,
    required this.label,
    this.active = false,
  });

  TexIoPin copyWith({bool? active}) =>
      TexIoPin(number: number, label: label, active: active ?? this.active);
}

// ─── Item de diagnóstico ──────────────────────────────────────────────────────

class TexDiagnostic {
  final String label;
  final bool hasError;

  const TexDiagnostic({required this.label, this.hasError = false});

  TexDiagnostic copyWith({bool? hasError}) =>
      TexDiagnostic(label: label, hasError: hasError ?? this.hasError);
}

// ─── Snapshot completo ────────────────────────────────────────────────────────

/// Fotografia imutável do estado da bancada TEX num instante.
///
/// As telas nunca alteram um snapshot; elas leem o último publicado pela
/// sessão e disparam comandos (start/stop/...) de volta. Cada atualização
/// gera um novo snapshot via [copyWith].
class TexSnapshot {
  final String programName;
  final int cameraNumber;
  final int totalCameras;

  final TexPhase phase;
  final TexResult result;

  /// Tempo decorrido na fase atual, em segundos.
  final double elapsedTime;

  final double pressao;
  final String pressaoUnit;
  final double vazamento;
  final String vazamentoUnit;

  /// Progresso do ciclo de 0.0 a 1.0.
  final double progresso;

  final bool running;
  final bool escapeBloqueado;

  final List<TexIoPin> inputs;
  final List<TexIoPin> outputs;

  final List<TexDiagnostic> autoCheck;
  final List<TexDiagnostic> diagnostico;

  /// Mensagem de alarme ativa, ou string vazia quando não há alarme.
  final String alarme;

  const TexSnapshot({
    this.programName = '#PRG TESTE',
    this.cameraNumber = 1,
    this.totalCameras = 1,
    this.phase = TexPhase.parado,
    this.result = TexResult.nenhum,
    this.elapsedTime = 0.0,
    this.pressao = 0.0,
    this.pressaoUnit = 'bar',
    this.vazamento = 0.0,
    this.vazamentoUnit = 'mbar/s',
    this.progresso = 0.0,
    this.running = false,
    this.escapeBloqueado = false,
    this.inputs = const [],
    this.outputs = const [],
    this.autoCheck = const [],
    this.diagnostico = const [],
    this.alarme = '',
  });

  bool get hasAlarme => alarme.isNotEmpty;

  /// Texto de status exibido no topo: o resultado quando o ciclo terminou,
  /// senão o nome da fase corrente.
  String get statusLabel =>
      phase == TexPhase.resultado && result != TexResult.nenhum
          ? result.label
          : phase.displayName;

  /// Cor semântica do status, resolvida sobre a paleta unificada [AppTheme].
  Color get statusColor {
    switch (result) {
      case TexResult.aprovado:
        return AppTheme.success;
      case TexResult.reprovado:
        return AppTheme.danger;
      case TexResult.nenhum:
        break;
    }
    if (phase == TexPhase.parado) return AppTheme.textSecondary;
    return AppTheme.accent;
  }

  TexSnapshot copyWith({
    String? programName,
    int? cameraNumber,
    int? totalCameras,
    TexPhase? phase,
    TexResult? result,
    double? elapsedTime,
    double? pressao,
    double? vazamento,
    double? progresso,
    bool? running,
    bool? escapeBloqueado,
    List<TexIoPin>? inputs,
    List<TexIoPin>? outputs,
    List<TexDiagnostic>? autoCheck,
    List<TexDiagnostic>? diagnostico,
    String? alarme,
  }) {
    return TexSnapshot(
      programName: programName ?? this.programName,
      cameraNumber: cameraNumber ?? this.cameraNumber,
      totalCameras: totalCameras ?? this.totalCameras,
      phase: phase ?? this.phase,
      result: result ?? this.result,
      elapsedTime: elapsedTime ?? this.elapsedTime,
      pressao: pressao ?? this.pressao,
      pressaoUnit: pressaoUnit,
      vazamento: vazamento ?? this.vazamento,
      vazamentoUnit: vazamentoUnit,
      progresso: progresso ?? this.progresso,
      running: running ?? this.running,
      escapeBloqueado: escapeBloqueado ?? this.escapeBloqueado,
      inputs: inputs ?? this.inputs,
      outputs: outputs ?? this.outputs,
      autoCheck: autoCheck ?? this.autoCheck,
      diagnostico: diagnostico ?? this.diagnostico,
      alarme: alarme ?? this.alarme,
    );
  }
}
