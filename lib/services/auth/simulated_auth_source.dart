import 'dart:math';
import '../../models/models.dart';
import '../data_sources.dart';

/// Autenticação simulada (Fase 1).
///
/// Valida localmente — qualquer usuário não vazio com senha de 4+ caracteres
/// entra, recebendo um perfil aleatório. Em produção, troque por uma
/// implementação que faça POST a um servidor e devolva o [AppUser] real.
class SimulatedAuthSource implements AuthSource {
  static final Random _rng = Random();

  static const List<AppUser> _usuarios = [
    AppUser(id: 'u1', name: 'Carlos Mendes', level: UserLevel.administrador),
    AppUser(id: 'u2', name: 'Ana Souza', level: UserLevel.supervisor),
    AppUser(id: 'u3', name: 'João Lima', level: UserLevel.operador),
  ];

  @override
  Future<AppUser?> login(String usuario, String senha) async {
    await Future<void>.delayed(const Duration(milliseconds: 800));
    if (usuario.trim().isEmpty || senha.length < 4) return null;
    return _usuarios[_rng.nextInt(_usuarios.length)];
  }
}
