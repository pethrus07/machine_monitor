// Modelos de domínio compartilhados por todo o app.
//
// Estes tipos não conhecem rede, UI ou persistência — são apenas dados.
// As fontes de dados ([MachineDataSource], [TexDataSource]) produzem estes
// modelos; as telas os consomem.

// ─── Usuário ──────────────────────────────────────────────────────────────────

/// Nível de acesso do operador. A ordem importa: o índice é o que vai para o
/// disco no [StorageService], então não reordene sem migrar os dados salvos.
enum UserLevel { operador, supervisor, administrador }

extension UserLevelLabel on UserLevel {
  String get label {
    switch (this) {
      case UserLevel.operador:
        return 'Operador';
      case UserLevel.supervisor:
        return 'Supervisor';
      case UserLevel.administrador:
        return 'Administrador';
    }
  }
}

class AppUser {
  final String id;
  final String name;
  final UserLevel level;

  const AppUser({required this.id, required this.name, required this.level});

  String get levelLabel => level.label;

  /// Primeiro nome — usado nas saudações da interface.
  String get firstName => name.split(' ').first;

  Map<String, dynamic> toJson() =>
      {'id': id, 'name': name, 'level': level.index};

  factory AppUser.fromJson(Map<String, dynamic> json) => AppUser(
        id: json['id'] as String,
        name: json['name'] as String,
        level: UserLevel.values[json['level'] as int],
      );
}

// ─── Tipo de máquina ──────────────────────────────────────────────────────────

/// Cada máquina cadastrada tem um tipo. O tipo decide qual tela de detalhe é
/// aberta e qual fonte de dados alimenta aquela máquina.
///
/// Para adicionar um novo tipo de equipamento ao sistema, acrescente um valor
/// aqui e trate-o em [MachineListScreen.openMachine] — todo o resto
/// (cadastro, lista, persistência) já é genérico.
enum MachineType {
  /// Monitoramento de produção/OEE (comportamento original do Machine Monitor).
  monitor,

  /// Bancada de teste de estanqueidade TEX "Anel Hídrico".
  tex,
}

extension MachineTypeMeta on MachineType {
  String get label {
    switch (this) {
      case MachineType.monitor:
        return 'Monitor de Produção';
      case MachineType.tex:
        return 'TEX – Anel Hídrico';
    }
  }

  /// Rótulo curto para chips/badges na lista.
  String get shortLabel {
    switch (this) {
      case MachineType.monitor:
        return 'Monitor';
      case MachineType.tex:
        return 'TEX';
    }
  }

  /// Persistido como string (e não índice) para sobreviver a reordenações.
  String get storageKey => name;

  static MachineType fromStorage(String? key) => MachineType.values.firstWhere(
        (t) => t.name == key,
        orElse: () => MachineType.monitor,
      );
}

// ─── Tipo de conexão ────────────────────────────────────────────────────────

/// Protocolo usado para falar com o CLP da máquina.
///
/// Conjunto inicial — ampliar conforme novos protocolos forem suportados.
/// Hoje só metadado de cadastro; o roteamento por protocolo entra quando cada
/// fonte de dados específica existir.
enum ConnectionType { modbusTcp, opcUa, mqtt }

extension ConnectionTypeMeta on ConnectionType {
  String get label {
    switch (this) {
      case ConnectionType.modbusTcp:
        return 'Modbus TCP';
      case ConnectionType.opcUa:
        return 'OPC-UA';
      case ConnectionType.mqtt:
        return 'MQTT';
    }
  }

  String get storageKey => name;

  static ConnectionType fromStorage(String? key) =>
      ConnectionType.values.firstWhere(
        (c) => c.name == key,
        orElse: () => ConnectionType.modbusTcp,
      );
}

// ─── Estado da máquina (Monitor) ────────────────────────────────────────────

enum MachineStatus { emCiclo, parada, manutencao }

extension MachineStatusLabel on MachineStatus {
  String get label {
    switch (this) {
      case MachineStatus.emCiclo:
        return 'Em Ciclo';
      case MachineStatus.parada:
        return 'Parada';
      case MachineStatus.manutencao:
        return 'Manutenção';
    }
  }
}

/// Estado da comunicação — independente do status operacional.
///
/// Uma máquina pode estar "parada" por decisão do operador (comunicação ok)
/// ou por falha de rede (sem comunicação). Os dois casos têm tratamento visual
/// diferente, por isso são modelados separadamente.
enum ConnectionStatus { ok, semComunicacao }

// ─── Indicadores de OEE ──────────────────────────────────────────────────────

class OEEData {
  final double disponibilidade;
  final double performance;
  final double qualidade;
  final double oeeGeral;

  const OEEData({
    required this.disponibilidade,
    required this.performance,
    required this.qualidade,
    required this.oeeGeral,
  });

  /// OEE zerado — usado em máquinas recém-cadastradas e estados sem dados.
  static const OEEData zero = OEEData(
    disponibilidade: 0,
    performance: 0,
    qualidade: 0,
    oeeGeral: 0,
  );
}

/// Produção de uma hora específica dentro do turno corrente.
class ProducaoHora {
  /// Hora do dia (0–23).
  final int hora;

  /// Peças produzidas nessa hora.
  final int producao;

  const ProducaoHora({required this.hora, required this.producao});
}

// ─── Máquina ──────────────────────────────────────────────────────────────────

class Machine {
  final String id;
  final String nome;
  final String ip;
  final MachineType type;

  /// Protocolo de comunicação com o CLP.
  final ConnectionType connection;

  final MachineStatus status;

  /// ok = CLP respondeu | semComunicacao = timeout ou erro de rede.
  final ConnectionStatus conexao;

  /// Produto rodando na máquina agora.
  final String produtoAtual;

  /// Acumulado de peças no dia corrente.
  final int producaoDia;

  /// Peças no ciclo/lote atual.
  final int producaoAtual;

  final String operador;
  final OEEData oee;

  /// Histórico de produção hora a hora do turno corrente.
  final List<ProducaoHora> producaoPorHora;

  const Machine({
    required this.id,
    required this.nome,
    required this.ip,
    this.type = MachineType.monitor,
    this.connection = ConnectionType.modbusTcp,
    this.status = MachineStatus.parada,
    this.conexao = ConnectionStatus.ok,
    this.produtoAtual = 'Sem produto',
    this.producaoDia = 0,
    this.producaoAtual = 0,
    this.operador = 'Não definido',
    this.oee = OEEData.zero,
    this.producaoPorHora = const [],
  });

  String get statusLabel => status.label;

  bool get semComunicacao => conexao == ConnectionStatus.semComunicacao;

  /// Atualiza apenas os campos informados, preservando o restante.
  ///
  /// Centraliza a "cópia com alterações" que antes era duplicada em cada fonte
  /// de dados (cada uma reconstruía a máquina campo a campo).
  Machine copyWith({
    MachineStatus? status,
    ConnectionStatus? conexao,
    String? produtoAtual,
    int? producaoDia,
    int? producaoAtual,
    String? operador,
    OEEData? oee,
    List<ProducaoHora>? producaoPorHora,
  }) {
    return Machine(
      id: id,
      nome: nome,
      ip: ip,
      type: type,
      connection: connection,
      status: status ?? this.status,
      conexao: conexao ?? this.conexao,
      produtoAtual: produtoAtual ?? this.produtoAtual,
      producaoDia: producaoDia ?? this.producaoDia,
      producaoAtual: producaoAtual ?? this.producaoAtual,
      operador: operador ?? this.operador,
      oee: oee ?? this.oee,
      producaoPorHora: producaoPorHora ?? this.producaoPorHora,
    );
  }

  /// Só persistimos a identidade da máquina (id/nome/ip/tipo). Os valores de
  /// produção são sempre relidos do CLP, nunca salvos.
  Map<String, dynamic> toJson() => {
        'id': id,
        'nome': nome,
        'ip': ip,
        'type': type.storageKey,
        'connection': connection.storageKey,
      };

  factory Machine.fromJson(Map<String, dynamic> json) => Machine(
        id: json['id'] as String,
        nome: json['nome'] as String,
        ip: json['ip'] as String,
        type: MachineTypeMeta.fromStorage(json['type'] as String?),
        connection:
            ConnectionTypeMeta.fromStorage(json['connection'] as String?),
      );
}
