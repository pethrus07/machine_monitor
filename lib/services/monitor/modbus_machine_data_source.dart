import 'package:logging/logging.dart';
import '../../core/network/ihm_inovance.dart';
import '../../models/models.dart';
import '../data_sources.dart';
import 'modbus_parser.dart';

/// Fonte real de máquinas tipo Monitor (Fase 2) via Modbus TCP/IP.
///
/// Mantém uma [IHMInovance] por máquina. A IHM conecta uma vez e fica lendo
/// continuamente; cada [fetchMachineData] apenas consulta os valores já
/// disponíveis em `LW[]` e os entrega ao [ModbusParser] — sem reabrir socket.
class ModbusMachineDataSource implements MachineDataSource {
  ModbusMachineDataSource({this.port = 502, this.unitId = 1});

  static final Logger _log = Logger('ModbusMachineDataSource');

  final int port;
  final int unitId;

  /// Cache de conexões por máquina: machineId → IHM.
  final Map<String, IHMInovance> _connections = {};

  @override
  Future<Machine> fetchMachineData(Machine machine) async {
    final ihm = await _ensureConnected(machine);
    if (ihm == null) {
      return machine.copyWith(conexao: ConnectionStatus.semComunicacao);
    }

    try {
      final regs = List<int>.generate(
        ModbusParser.registradoresNecessarios,
        (i) => ihm.LW[i] is int ? ihm.LW[i] as int : 0,
      );

      // Tudo zero + desconectada → ainda não há leitura válida.
      if (regs.every((v) => v == 0) && !ihm.isConnected) {
        return machine.copyWith(conexao: ConnectionStatus.semComunicacao);
      }

      final parsed = ModbusParser.parse(machine, regs);
      _log.fine(
        '${machine.nome} (${machine.ip}): ${parsed.statusLabel}, '
        'dia=${parsed.producaoDia}, OEE=${parsed.oee.oeeGeral.toStringAsFixed(1)}%',
      );
      return parsed;
    } catch (e) {
      _log.severe('${machine.nome} (${machine.ip}): erro no parse → $e');
      return machine.copyWith(conexao: ConnectionStatus.semComunicacao);
    }
  }

  @override
  Future<List<Machine>> fetchAll(List<Machine> machines) =>
      Future.wait(machines.map(fetchMachineData));

  /// Garante uma IHM conectada para a máquina; recria se a anterior caiu.
  Future<IHMInovance?> _ensureConnected(Machine machine) async {
    final existing = _connections[machine.id];
    if (existing != null && existing.isConnected) return existing;

    if (existing != null) {
      try {
        await existing.disconnect();
      } catch (_) {}
    }

    try {
      final ihm = IHMInovance();
      await ihm.connect(host: machine.ip, port: port, unitId: unitId);
      _connections[machine.id] = ihm;
      _log.info('${machine.nome} (${machine.ip}): IHM conectada');
      return ihm;
    } catch (e) {
      _log.severe('${machine.nome} (${machine.ip}): falha ao conectar → $e');
      _connections.remove(machine.id);
      return null;
    }
  }

  @override
  Future<void> dispose() async {
    for (final ihm in _connections.values) {
      try {
        await ihm.disconnect();
      } catch (_) {}
    }
    _connections.clear();
  }
}
