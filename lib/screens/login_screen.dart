import 'package:flutter/material.dart';
import '../services/data_sources.dart';
import '../services/storage/storage_service.dart';
import '../core/theme/app_theme.dart';
import 'machine_list_screen.dart';

/// Tela de entrada do sistema.
///
/// Autentica via [AppDataSource.auth] (simulada ou real, decidido no `main`),
/// salva a sessão e segue para a lista de máquinas.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _usuarioCtrl = TextEditingController();
  final _senhaCtrl = TextEditingController();
  bool _loading = false;
  bool _obscure = true;
  String? _erro;

  late final AnimationController _animCtrl;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _fade = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    _usuarioCtrl.dispose();
    _senhaCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    setState(() {
      _loading = true;
      _erro = null;
    });

    final user = await AppDataSource.auth.login(
      _usuarioCtrl.text.trim(),
      _senhaCtrl.text,
    );
    if (!mounted) return;

    if (user == null) {
      setState(() {
        _loading = false;
        _erro = 'Usuário ou senha inválidos.';
      });
      return;
    }

    await StorageService.saveSession(user);
    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => MachineListScreen(user: user)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tablet = AppTheme.isTablet(context);
    final maxW = tablet ? 480.0 : double.infinity;

    return Scaffold(
      body: FadeTransition(
        opacity: _fade,
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding:
                  EdgeInsets.symmetric(horizontal: tablet ? 0 : 28, vertical: 32),
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxW),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(child: _Logo(tablet: tablet)),
                    SizedBox(height: tablet ? 64 : 48),

                    const _FieldLabel('Usuário'),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _usuarioCtrl,
                      style: const TextStyle(color: AppTheme.textPrimary),
                      decoration: const InputDecoration(
                        hintText: 'Digite seu usuário',
                        prefixIcon: Icon(Icons.person_outline,
                            color: AppTheme.textSecondary, size: 20),
                      ),
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 20),

                    const _FieldLabel('Senha'),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _senhaCtrl,
                      obscureText: _obscure,
                      style: const TextStyle(color: AppTheme.textPrimary),
                      decoration: InputDecoration(
                        hintText: 'Digite sua senha',
                        prefixIcon: const Icon(Icons.lock_outline,
                            color: AppTheme.textSecondary, size: 20),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscure
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            color: AppTheme.textSecondary,
                            size: 20,
                          ),
                          onPressed: () => setState(() => _obscure = !_obscure),
                        ),
                      ),
                      onSubmitted: (_) => _login(),
                    ),

                    if (_erro != null) ...[
                      const SizedBox(height: 14),
                      _ErrorBox(_erro!),
                    ],

                    const SizedBox(height: 32),
                    ElevatedButton(
                      onPressed: _loading ? null : _login,
                      child: _loading
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : const Text('Entrar'),
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Logo extends StatelessWidget {
  const _Logo({required this.tablet});
  final bool tablet;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: tablet ? 96 : 80,
          height: tablet ? 96 : 80,
          decoration: BoxDecoration(
            color: AppTheme.surfaceCard,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppTheme.border),
          ),
          child: Icon(
            Icons.precision_manufacturing_outlined,
            size: tablet ? 48 : 40,
            color: AppTheme.accent,
          ),
        ),
        SizedBox(height: tablet ? 32 : 24),
        Text(
          'MACHINE MONITOR',
          style: TextStyle(
            fontFamily: 'monospace',
            fontSize: tablet ? 24 : 20,
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary,
            letterSpacing: 3,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Sistema de monitoramento industrial',
          style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
        ),
      ],
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 13,
        color: AppTheme.textSecondary,
        fontWeight: FontWeight.w500,
      ),
    );
  }
}

class _ErrorBox extends StatelessWidget {
  const _ErrorBox(this.message);
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.danger.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.danger.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: AppTheme.danger, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: AppTheme.danger, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
