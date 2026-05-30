import 'dart:math';
import '../../models/models.dart';
import '../data_sources.dart';
import 'modbus_parser.dart';

/// Fonte simulada de máquinas tipo Monitor (Fase 1).
///
/// Gera um array de registradores plausível e o passa pelo mesmo
/// [ModbusParser] usado no modo real — assim a simulação exercita exatamente o
/// caminho de parsing de produção. Cerca de 10% das leituras simulam queda de
/// rede, devolvendo a máquina com [ConnectionStatus.semComunicacao].
class SimulatedMachineDataSource implements MachineDataSource {
  static final Random _rng = Random();

  static const Duration _timeout = Duration(seconds: 5);

  @override
  Future<Machine> fetchMachineData(Machine machine) async {
    // Falha de comunicação ocasional — aguarda o timeout cheio, como o real.
    if (_rng.nextDouble() < 0.10) {
      await Future<void>.delayed(_timeout);
      return machine.copyWith(conexao: ConnectionStatus.semComunicacao);
    }

    await Future<void>.delayed(const Duration(milliseconds: 400));
    final regs = _gerarRegistradores();
    return ModbusParser.parse(machine, regs);
  }

  @override
  Future<List<Machine>> fetchAll(List<Machine> machines) =>
      Future.wait(machines.map(fetchMachineData));

  /// Nada a liberar na simulação (sem sockets/timers). Implementado apenas para
  /// satisfazer o contrato de [MachineDataSource], já que `implements` descarta
  /// o corpo padrão definido na interface.
  @override
  Future<void> dispose() async {}

  /// Monta um bloco de registradores coerente com [ModbusParser].
  List<int> _gerarRegistradores() {
    final roll = _rng.nextDouble();
    final int statusRaw = roll < 0.70 ? 1 : (roll < 0.85 ? 0 : 2);
    final emCiclo = statusRaw == 1;

    final disp = emCiclo ? 700 + _rng.nextInt(250) : 0;
    final perf = emCiclo ? 650 + _rng.nextInt(300) : 0;
    final qual = emCiclo ? 800 + _rng.nextInt(180) : 0;
    final oeeGeral = emCiclo
        ? ((disp / 1000) * (perf / 1000) * (qual / 1000) * 1000).round()
        : 0;

    final producaoDia = emCiclo ? 800 + _rng.nextInt(3200) : 0;

    final regs = <int>[
      statusRaw,
      producaoDia & 0xFFFF,
      (producaoDia >> 16) & 0xFFFF,
      emCiclo ? 50 + _rng.nextInt(200) : 0, // ciclo
      oeeGeral, disp, perf, qual,
      emCiclo ? 1 + _rng.nextInt(5) : 0, // produto
      emCiclo ? 1 + _rng.nextInt(5) : 0, // operador
    ];

    // Produção hora a hora do turno corrente.
    final agora = DateTime.now().hour;
    const n = ModbusParser.horasPorTurno;
    for (var i = 0; i < n; i++) {
      var hora = (agora - (n - 1 - i)) % 24;
      if (hora < 0) hora += 24;
      final prod = emCiclo
          ? (i < n - 1 ? 60 + _rng.nextInt(120) : 10 + _rng.nextInt(60))
          : 0;
      regs..add(hora)..add(prod);
    }
    return regs;
  }
}
