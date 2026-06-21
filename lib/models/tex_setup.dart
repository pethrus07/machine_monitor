/// Configuração de teste de uma bancada TEX, definida pelo operador no app.
///
/// Diferente do [TexSnapshot] (que é lido do CLP), esta configuração vive no
/// lado do app e é persistida por máquina. Hoje cobre:
///   • [bcd] — código BCD selecionado (este **é** escrito no CLP, reg 2);
///   • [selectedChamber] + [testsPerChamber] — câmara ativa e quantos testes
///     cada câmara executa (ajuste local; ainda sem registrador confirmado no
///     CLP — ver TODO na fonte de dados).
class TexSetup {
  const TexSetup({
    this.bcd = 0,
    this.selectedChamber = 1,
    this.testsPerChamber = const [1],
  });

  /// Limites de interface (evitam valores absurdos nos seletores).
  static const int maxBcd = 15;
  static const int maxChambers = 16;
  static const int maxTests = 99;

  /// Código BCD enviado ao CLP.
  final int bcd;

  /// Câmara ativa (1-based).
  final int selectedChamber;

  /// Quantidade de testes por câmara — índice 0 = câmara 1.
  final List<int> testsPerChamber;

  /// Número de câmaras configuradas.
  int get chamberCount => testsPerChamber.length;

  /// Testes configurados para a câmara ativa.
  int get currentTests => testsFor(selectedChamber);

  int testsFor(int chamber) {
    final i = chamber - 1;
    return (i >= 0 && i < testsPerChamber.length) ? testsPerChamber[i] : 1;
  }

  TexSetup copyWith({
    int? bcd,
    int? selectedChamber,
    List<int>? testsPerChamber,
  }) {
    return TexSetup(
      bcd: bcd ?? this.bcd,
      selectedChamber: selectedChamber ?? this.selectedChamber,
      testsPerChamber: testsPerChamber ?? this.testsPerChamber,
    );
  }

  /// Define o BCD, respeitando o intervalo válido (0..[maxBcd]).
  TexSetup withBcd(int value) => copyWith(bcd: value.clamp(0, maxBcd));

  /// Seleciona uma câmara. Ao navegar para uma câmara ainda não configurada,
  /// a lista cresce com 1 teste por câmara nova.
  TexSetup selectChamber(int chamber) {
    final target = chamber.clamp(1, maxChambers);
    if (target <= testsPerChamber.length) {
      return copyWith(selectedChamber: target);
    }
    final grown = [
      ...testsPerChamber,
      for (var i = testsPerChamber.length; i < target; i++) 1,
    ];
    return copyWith(selectedChamber: target, testsPerChamber: grown);
  }

  /// Ajusta a quantidade de testes da câmara ativa (1..[maxTests]).
  TexSetup withTestsForCurrent(int tests) {
    final list = List<int>.from(testsPerChamber);
    final i = selectedChamber - 1;
    if (i < 0 || i >= list.length) return this;
    list[i] = tests.clamp(1, maxTests);
    return copyWith(testsPerChamber: list);
  }

  Map<String, dynamic> toJson() => {
        'bcd': bcd,
        'selectedChamber': selectedChamber,
        'testsPerChamber': testsPerChamber,
      };

  factory TexSetup.fromJson(Map<String, dynamic> json) {
    final raw = json['testsPerChamber'];
    final tests = raw is List && raw.isNotEmpty
        ? raw.map((e) => (e as num).toInt().clamp(1, maxTests)).toList()
        : const [1];
    final count = tests.length;
    return TexSetup(
      bcd: (json['bcd'] as num?)?.toInt().clamp(0, maxBcd) ?? 0,
      selectedChamber:
          (json['selectedChamber'] as num?)?.toInt().clamp(1, count) ?? 1,
      testsPerChamber: tests,
    );
  }
}
