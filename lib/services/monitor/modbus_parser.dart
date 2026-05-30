import '../../models/models.dart';

/// Traduz o bloco bruto de Holding Registers do CLP para o modelo [Machine].
///
/// Layout (26 registradores de 16 bits):
///
/// BLOCO FIXO (índices 0–9)
/// ┌───────┬──────────────────────────────────┬──────────────────────────────┐
/// │ Índice│ Descrição                        │ Escala / codificação         │
/// ├───────┼──────────────────────────────────┼──────────────────────────────┤
/// │   0   │ Status da máquina                │ 0=Parada 1=EmCiclo 2=Manut.  │
/// │   1   │ Produção do dia (LOW)            │ uint16 — parte baixa         │
/// │   2   │ Produção do dia (HIGH)           │ uint16 — parte alta → 32 bits│
/// │   3   │ Produção do ciclo atual          │ uint16                       │
/// │   4   │ OEE Geral × 10                   │ 823 → 82.3 %                 │
/// │   5   │ Disponibilidade × 10             │ 910 → 91.0 %                 │
/// │   6   │ Performance × 10                 │ 876 → 87.6 %                 │
/// │   7   │ Qualidade × 10                   │ 995 → 99.5 %                 │
/// │   8   │ Código do produto                │ resolvido em [produtos]      │
/// │   9   │ Código do operador               │ resolvido em [operadores]    │
/// └───────┴──────────────────────────────────┴──────────────────────────────┘
///
/// BLOCO DINÂMICO (índice 10+): produção hora a hora — [horasPorTurno] pares
/// `[hora, peças]`, cada par ocupando 2 registradores.
///
/// Como adicionar um campo: reserve um índice livre, crie a constante `_iXxx` e
/// leia-o em [parse]. Como mudar o tamanho do turno: ajuste [horasPorTurno].
class ModbusParser {
  ModbusParser._();

  /// Horas exibidas no gráfico (tamanho do turno).
  static const int horasPorTurno = 8;

  static const int _base = 10;
  static const int registradoresNecessarios = _base + (horasPorTurno * 2);

  /// Código → nome do produto. Em produção pode vir de REST/SQLite.
  static const Map<int, String> produtos = {
    0: 'Sem produto',
    1: 'Corpo Válvula VX-10',
    2: 'Flange DN50',
    3: 'Pinhão Helicoidal M3',
    4: 'Eixo Escalonado 45mm',
    5: 'Tampa Mancal BT206',
  };

  /// Código → nome do operador.
  static const Map<int, String> operadores = {
    0: 'Não definido',
    1: 'Paulo Ferreira',
    2: 'Maria Santos',
    3: 'Lucas Oliveira',
    4: 'Fernanda Costa',
    5: 'Ricardo Alves',
  };

  // Índices do bloco fixo.
  static const int _iStatus = 0;
  static const int _iProdDiaLow = 1;
  static const int _iProdDiaHigh = 2;
  static const int _iProdCiclo = 3;
  static const int _iOeeGeral = 4;
  static const int _iDisp = 5;
  static const int _iPerf = 6;
  static const int _iQual = 7;
  static const int _iProduto = 8;
  static const int _iOperador = 9;

  /// Converte o array de registradores em uma [Machine] preenchida, mantendo
  /// id/nome/ip/tipo da máquina-base.
  static Machine parse(Machine base, List<int> regs) {
    _validate(regs);

    final producaoDia =
        (regs[_iProdDiaHigh] << 16) | (regs[_iProdDiaLow] & 0xFFFF);

    final oee = OEEData(
      oeeGeral: _scale10(regs[_iOeeGeral]),
      disponibilidade: _scale10(regs[_iDisp]),
      performance: _scale10(regs[_iPerf]),
      qualidade: _scale10(regs[_iQual]),
    );

    final porHora = <ProducaoHora>[];
    for (var i = 0; i < horasPorTurno; i++) {
      final offset = _base + (i * 2);
      porHora.add(ProducaoHora(
        hora: regs[offset],
        producao: regs[offset + 1],
      ));
    }

    return base.copyWith(
      status: _parseStatus(regs[_iStatus]),
      conexao: ConnectionStatus.ok,
      produtoAtual:
          produtos[regs[_iProduto]] ?? 'Produto #${regs[_iProduto]}',
      producaoDia: producaoDia,
      producaoAtual: regs[_iProdCiclo],
      operador:
          operadores[regs[_iOperador]] ?? 'Operador #${regs[_iOperador]}',
      oee: oee,
      producaoPorHora: porHora,
    );
  }

  static void _validate(List<int> regs) {
    if (regs.length < registradoresNecessarios) {
      throw ModbusParserException(
        'Array insuficiente: esperado $registradoresNecessarios, '
        'recebido ${regs.length}.',
      );
    }
    for (var i = 0; i < registradoresNecessarios; i++) {
      if (regs[i] < 0 || regs[i] > 0xFFFF) {
        throw ModbusParserException('Reg[$i] fora do range uint16: ${regs[i]}');
      }
    }
  }

  static MachineStatus _parseStatus(int raw) {
    switch (raw) {
      case 1:
        return MachineStatus.emCiclo;
      case 2:
        return MachineStatus.manutencao;
      default:
        return MachineStatus.parada;
    }
  }

  static double _scale10(int raw) => raw / 10.0;
}

class ModbusParserException implements Exception {
  final String message;
  const ModbusParserException(this.message);
  @override
  String toString() => 'ModbusParserException: $message';
}
