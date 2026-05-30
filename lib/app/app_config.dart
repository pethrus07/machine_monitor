/// Configuração central do app, resolvida uma vez no `main()`.
///
/// Concentra o que antes estava espalhado em constantes soltas (a flag
/// `kUsarModbusReal`, a porta 502, os intervalos de polling). Trocar entre
/// simulação e Modbus real é mudar [useRealModbus] em um único lugar.
class AppConfig {
  const AppConfig({
    this.useRealModbus = true,
    this.modbusPort = 502,
    this.unitId = 1,
    this.listPollInterval = const Duration(seconds: 10),
    this.detailPollInterval = const Duration(seconds: 2),
    this.texRefreshInterval = const Duration(milliseconds: 100),
  });

  /// `true` → conecta nos CLPs via Modbus TCP/IP.
  /// `false` → usa as fontes simuladas (testes sem CLP).
  final bool useRealModbus;

  /// Porta Modbus padrão dos CLPs.
  final int modbusPort;

  /// Unit ID (endereço do escravo) Modbus.
  final int unitId;

  /// Polling da lista de máquinas (várias máquinas em paralelo).
  final Duration listPollInterval;

  /// Polling da tela de detalhe (uma máquina, pode ser mais frequente).
  final Duration detailPollInterval;

  /// Cadência de atualização do console TEX (HMI ao vivo).
  final Duration texRefreshInterval;
}
