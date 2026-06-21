import '../../models/tex_models.dart';

/// Tradução dos campos crus da bancada TEX ([TexData]) para os tipos de UI.
///
/// O layout de registradores em si (offsets, floats) vive em
/// [registersToTexData] (`models/tex_data.dart`) e foi verificado contra o
/// equipamento. Aqui ficam as conversões "de negócio": bitfields → pinos/
/// diagnósticos, e códigos de status → fase/resultado.
///
/// Onde o significado dos códigos do CLP ainda não está documentado, o default
/// é conservador e o ponto está marcado para ajuste fino em campo.
class TexRegisterMap {
  TexRegisterMap._();

  // ── Bits de [TexData.digitalOutputs] ─────────────────────────────────────────
  // Alinhados com [outputLabels]: bit i ↔ outputLabels[i].
  static const int bitDigital1 = 0;
  static const int bitAprova = 1;
  static const int bitReprovaTeste = 2;
  static const int bitBusy = 7;

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

  /// `true` se o bit [index] estiver setado em [bitfield].
  static bool bit(int bitfield, int index) => (bitfield & (1 << index)) != 0;

  /// Fase do ciclo a partir do `testStatus` (reg 18).
  ///
  /// TODO(tex): mapear os códigos exatos do CLP. Por ora só distinguimos
  /// "parado" (0) de "em andamento" — qualquer valor != 0 entra como
  /// [TexPhase.medicao] (AVALIANDO), suficiente para indicar atividade.
  static TexPhase phaseFromStatus(int testStatus) {
    if (testStatus == 0) return TexPhase.parado;
    return TexPhase.medicao;
  }

  /// Resultado do teste a partir dos bits de saída ([TexData.digitalOutputs]).
  static TexResult resultFromOutputs(int digitalOutputs) {
    if (bit(digitalOutputs, bitReprovaTeste)) return TexResult.reprovado;
    if (bit(digitalOutputs, bitAprova)) return TexResult.aprovado;
    return TexResult.nenhum;
  }

  /// `true` enquanto o ciclo está rodando (saída BUSY ou status != parado).
  static bool runningFrom(int digitalOutputs, int testStatus) =>
      testStatus != 0 || bit(digitalOutputs, bitBusy);

  /// Constrói a lista de pinos a partir de um bitfield, um bit por rótulo.
  static List<TexIoPin> pinsFromBits(List<String> labels, int bitfield) {
    return List<TexIoPin>.generate(labels.length, (i) {
      return TexIoPin(number: i + 1, label: labels[i], active: bit(bitfield, i));
    });
  }

  static List<TexDiagnostic> diagsFromBits(List<String> labels, int bitfield) {
    return List<TexDiagnostic>.generate(labels.length, (i) {
      return TexDiagnostic(label: labels[i], hasError: bit(bitfield, i));
    });
  }
}
