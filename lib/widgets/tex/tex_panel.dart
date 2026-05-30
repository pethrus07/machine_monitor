import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

/// Painel base do console TEX: fundo em gradiente, borda fina e um leve brilho
/// na cor de destaque. Substitui o antigo `TexStyles.panelDecoration`, agora
/// falando a mesma linguagem visual do resto do app ([AppTheme]).
class TexPanel extends StatelessWidget {
  const TexPanel({
    super.key,
    required this.child,
    this.accent,
    this.padding,
  });

  final Widget child;

  /// Cor da borda/brilho. Quando nula, usa o ciano padrão.
  final Color? accent;

  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final color = accent ?? AppTheme.accent;
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        gradient: AppTheme.panelGradient,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(color: color.withValues(alpha: 0.35)),
        boxShadow: [
          BoxShadow(color: color.withValues(alpha: 0.10), blurRadius: 12),
        ],
      ),
      child: child,
    );
  }
}

/// Painel com cabeçalho titulado — usado nas listas de E-S e diagnóstico.
class TexTitledPanel extends StatelessWidget {
  const TexTitledPanel({
    super.key,
    required this.title,
    required this.child,
    this.accent,
  });

  final String title;
  final Widget child;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    return TexPanel(
      accent: accent,
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: AppTheme.surfaceElevated.withValues(alpha: 0.4),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(AppTheme.radius),
              ),
            ),
            child: Center(
              child: Text(
                title,
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 15,
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.w700,
                  letterSpacing: 2,
                ),
              ),
            ),
          ),
          Expanded(child: child),
        ],
      ),
    );
  }
}
