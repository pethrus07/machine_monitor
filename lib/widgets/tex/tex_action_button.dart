import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

/// Botão de comando do painel TEX (START / STOP / BLOQUEIO).
///
/// Estilo HMI: contorno luminoso quando pronto e **preenchido** quando ativo,
/// com resposta tátil fluida — afunda (escala) e suaviza o brilho ao toque.
/// A [active] liga o preenchimento de estado (START verde rodando, BLOQUEIO
/// vermelho engatado); a [color] define a cor do realce. Sem cor, usa o ciano
/// padrão. As transições são animadas para dar a sensação de painel físico.
class TexActionButton extends StatefulWidget {
  const TexActionButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
    this.active = false,
    this.height = 64,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  /// Cor de realce. Quando nula, usa o ciano padrão.
  final Color? color;

  /// Estado engatado — preenche o botão e intensifica o brilho.
  final bool active;

  final double height;

  @override
  State<TexActionButton> createState() => _TexActionButtonState();
}

class _TexActionButtonState extends State<TexActionButton> {
  bool _pressed = false;

  void _setPressed(bool v) {
    if (_pressed != v) setState(() => _pressed = v);
  }

  @override
  Widget build(BuildContext context) {
    final accent = widget.color ?? AppTheme.accent;
    final active = widget.active;

    // Conteúdo de alto contraste quando preenchido; senão, na cor de realce.
    final fg = active ? AppTheme.surfaceDeep : accent;

    return GestureDetector(
      onTapDown: (_) => _setPressed(true),
      onTapUp: (_) {
        _setPressed(false);
        widget.onTap();
      },
      onTapCancel: () => _setPressed(false),
      child: AnimatedScale(
        scale: _pressed ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOut,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          height: widget.height,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: active
                  ? [accent, Color.lerp(accent, Colors.black, 0.30)!]
                  : const [AppTheme.surfaceElevated, AppTheme.surfaceCard],
            ),
            borderRadius: BorderRadius.circular(AppTheme.radius),
            border: Border.all(
              color: active ? accent : accent.withValues(alpha: 0.55),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: accent.withValues(
                  alpha: _pressed ? 0.10 : (active ? 0.45 : 0.18),
                ),
                blurRadius: _pressed ? 6 : (active ? 20 : 10),
                spreadRadius: active && !_pressed ? 1 : 0,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(widget.icon, color: fg, size: 32),
              if (widget.label.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  widget.label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: fg,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.8,
                    height: 1.15,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
