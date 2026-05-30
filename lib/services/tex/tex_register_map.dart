import '../../models/tex_models.dart';

/// Mapa de endereços Modbus da bancada TEX.
///
/// O app original da TEX só tinha simulação — nunca leu um CLP. Este arquivo é
/// o contrato de integração: descreve onde cada grandeza mora nos mapas LW
/// (registradores) e LB (coils) da IHM. Ajuste os endereços conforme a
/// programação real do CLP; a [ModbusTexDataSource] lê/escreve exatamente daqui.
///
/// Convenção: LW = Holding Registers (valores), LB = Coils (bits).
class TexRegisterMap {
  TexRegisterMap._();

  // ── Leitura de valores (LW) ──────────────────────────────────────────────────
  /// Fase do ciclo (mapeada por [phaseFromCode]).
  static const int lwPhase = 0;

  /// Pressão atual × 1000 (ex.: 999 → 0.999 bar).
  static const int lwPressao = 1;

  /// Vazamento × 1000 (ex.: 15 → 0.015 mbar/s).
  static const int lwVazamento = 2;

  /// Progresso do ciclo em % (0–100).
  static const int lwProgresso = 3;

  /// Tempo decorrido na fase × 10 (ex.: 35 → 3.5 s).
  static const int lwElapsed = 4;

  /// Câmara atual e total.
  static const int lwCamaraAtual = 5;
  static const int lwCamaraTotal = 6;

  /// Resultado do último teste (0=nenhum, 1=aprovado, 2=reprovado).
  static const int lwResultado = 7;

  // ── Comandos (LB de escrita) ─────────────────────────────────────────────────
  static const int coilStart = 0;
  static const int coilStop = 1;
  static const int coilBlockEscape = 2;
  static const int coilNextCamera = 3;
  static const int coilPrevCamera = 4;

  // ── Entradas digitais (LB de leitura) ────────────────────────────────────────
  /// Primeira coil das 8 entradas (sequenciais).
  static const int coilInputsBase = 100;

  /// Primeira coil das 8 saídas (sequenciais).
  static const int coilOutputsBase = 120;

  /// Primeira coil dos 10 itens de auto-check.
  static const int coilAutoCheckBase = 140;

  /// Primeira coil dos 8 itens de diagnóstico de saída.
  static const int coilDiagnosticoBase = 160;

  // ── Rótulos fixos (não vêm do CLP) ───────────────────────────────────────────
  static const List<String> inputLabels = [
    'BCD 0',
    'BCD 1',
    'PARADA',
    'INÍCIO',
    'BCD 2 / SENSOR DE REFUGO',
    'BCD 3 / PEÇA ANTERIOR',
    'BCD 4 / PRÓXIMA PEÇA',
    'BLOQUEIA ESCAPE',
  ];

  static const List<String> outputLabels = [
    'DIGITAL 1',
    'APROVA',
    'REPROVA TESTE',
    'DIGITAL 2 / REPROVA REF.',
    'DIGITAL 3 / FALHA',
    'RETRABALHO',
    'ESCAPE EXTERNO',
    'BUSY',
  ];

  static const List<String> autoCheckLabels = [
    'VÁLVULA 1 COM PROBLEMA',
    'VÁLVULA 2 COM PROBLEMA',
    'VÁLVULA 3 COM PROBLEMA',
    'VÁLVULA 4 COM PROBLEMA',
    'VÁLVULA 5 COM PROBLEMA',
    'VÁLVULA 6 COM PROBLEMA',
    'VÁLVULA 7 COM PROBLEMA',
    'VÁLVULA 8 COM PROBLEMA',
    'FALHA SENSOR DIFERENCIAL/FLUXO',
    'FALHA SENSOR PRESSÃO DE TESTE',
  ];

  static const List<String> diagnosticoLabels = [
    'SAÍDA 1 COM PROBLEMA',
    'SAÍDA 2 COM PROBLEMA',
    'SAÍDA 3 COM PROBLEMA',
    'SAÍDA 4 COM PROBLEMA',
    'SAÍDA 5 COM PROBLEMA',
    'SAÍDA 6 COM PROBLEMA',
    'SAÍDA 7 COM PROBLEMA',
    'SAÍDA 8 COM PROBLEMA',
  ];

  // ── Conversões ───────────────────────────────────────────────────────────────
  static TexPhase phaseFromCode(int code) {
    switch (code) {
      case 1:
        return TexPhase.enchimento;
      case 2:
        return TexPhase.equalizacao;
      case 3:
        return TexPhase.estabilizacao;
      case 4:
        return TexPhase.medicao;
      case 5:
        return TexPhase.escape;
      case 6:
        return TexPhase.resultado;
      default:
        return TexPhase.parado;
    }
  }

  static TexResult resultFromCode(int code) {
    switch (code) {
      case 1:
        return TexResult.aprovado;
      case 2:
        return TexResult.reprovado;
      default:
        return TexResult.nenhum;
    }
  }

  /// Constrói a lista de pinos a partir das coils lidas, começando em [base].
  static List<TexIoPin> pinsFrom(
    List<String> labels,
    bool Function(int coil) read,
    int base,
  ) {
    return List<TexIoPin>.generate(labels.length, (i) {
      return TexIoPin(
        number: i + 1,
        label: labels[i],
        active: read(base + i),
      );
    });
  }

  static List<TexDiagnostic> diagsFrom(
    List<String> labels,
    bool Function(int coil) read,
    int base,
  ) {
    return List<TexDiagnostic>.generate(labels.length, (i) {
      return TexDiagnostic(label: labels[i], hasError: read(base + i));
    });
  }
}
