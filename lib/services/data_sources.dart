import 'package:flutter/foundation.dart';
import '../models/models.dart';
import '../models/tex_models.dart';

/// Contratos das fontes de dados e o registro global que as injeta.
///
/// Este é o eixo da arquitetura: as telas dependem só destas interfaces, nunca
/// das implementações concretas. Quem decide se o app fala com CLP real ou com
/// simulação é o `main()`, ao chamar [AppDataSource.init] — nenhuma tela muda.

// ─── Autenticação ─────────────────────────────────────────────────────────────

abstract class AuthSource {
  /// Retorna o usuário autenticado, ou `null` se as credenciais forem inválidas.
  Future<AppUser?> login(String usuario, String senha);
}

// ─── Máquinas tipo Monitor ────────────────────────────────────────────────────

abstract class MachineDataSource {
  /// Lê o estado atual de uma máquina (status, OEE, produção...).
  Future<Machine> fetchMachineData(Machine machine);

  /// Lê várias máquinas em paralelo.
  Future<List<Machine>> fetchAll(List<Machine> machines);

  /// Libera conexões/recursos. Chamado ao encerrar o app.
  Future<void> dispose() async {}
}

// ─── Máquinas tipo TEX ────────────────────────────────────────────────────────

/// Sessão ao vivo de uma bancada TEX.
///
/// Ao contrário do monitor (que faz polling pontual), a bancada TEX é uma HMI
/// contínua: a sessão publica um fluxo de [TexSnapshot] via [snapshot] e recebe
/// comandos de volta. A tela cria a sessão ao abrir e a descarta ao fechar.
abstract class TexSession {
  /// Último estado publicado — observável pela tela.
  ValueListenable<TexSnapshot> get snapshot;

  void start();
  void stop();
  void toggleEscapeBlock();

  /// Seleciona o código BCD na bancada (escrito no CLP).
  void setBcd(int value);

  Future<void> dispose();
}

abstract class TexDataSource {
  /// Abre uma sessão ao vivo para a [machine] informada.
  TexSession connect(Machine machine);
}

// ─── Registro global (injeção de dependência) ────────────────────────────────

/// Ponto único de acesso às fontes ativas.
///
/// Para migrar de simulação para Modbus real, basta chamar [init] com outras
/// implementações no `main()`. As telas continuam idênticas.
class AppDataSource {
  AppDataSource._();

  static AuthSource? _auth;
  static MachineDataSource? _machines;
  static TexDataSource? _tex;

  static AuthSource get auth {
    assert(_auth != null, 'Chame AppDataSource.init() no main().');
    return _auth!;
  }

  static MachineDataSource get machines {
    assert(_machines != null, 'Chame AppDataSource.init() no main().');
    return _machines!;
  }

  static TexDataSource get tex {
    assert(_tex != null, 'Chame AppDataSource.init() no main().');
    return _tex!;
  }

  static void init({
    required AuthSource auth,
    required MachineDataSource machines,
    required TexDataSource tex,
  }) {
    _auth = auth;
    _machines = machines;
    _tex = tex;
  }
}
