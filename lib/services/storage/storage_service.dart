import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/models.dart';
import '../../models/tex_setup.dart';

/// Persistência local via SharedPreferences.
///
/// Guarda apenas a identidade das máquinas (id/nome/ip/tipo) e a sessão do
/// usuário. Os valores de produção nunca são salvos — são sempre relidos do CLP.
class StorageService {
  StorageService._();

  // Versão na chave permite migrar o formato no futuro sem ler lixo antigo.
  static const String _keyMachines = 'machines_v3';
  static const String _keySession = 'session_user';

  static Future<void> saveMachines(List<Machine> machines) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _keyMachines,
      machines.map((m) => jsonEncode(m.toJson())).toList(),
    );
  }

  static Future<List<Machine>> loadMachines() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_keyMachines) ?? const [];
    return raw
        .map((s) => Machine.fromJson(jsonDecode(s) as Map<String, dynamic>))
        .toList();
  }

  static Future<void> saveSession(AppUser user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keySession, jsonEncode(user.toJson()));
  }

  static Future<AppUser?> loadSession() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keySession);
    if (raw == null) return null;
    try {
      return AppUser.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      // Sessão corrompida/antiga — ignora e pede login de novo.
      return null;
    }
  }

  static Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keySession);
  }

  // ── Configuração de teste TEX (por máquina) ──────────────────────────────────

  static String _texSetupKey(String machineId) => 'tex_setup_$machineId';

  static Future<void> saveTexSetup(String machineId, TexSetup setup) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_texSetupKey(machineId), jsonEncode(setup.toJson()));
  }

  /// Carrega a configuração da máquina, ou uma [TexSetup] padrão se não houver.
  static Future<TexSetup> loadTexSetup(String machineId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_texSetupKey(machineId));
    if (raw == null) return const TexSetup();
    try {
      return TexSetup.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return const TexSetup();
    }
  }
}
