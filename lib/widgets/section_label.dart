import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';

/// Rótulo de seção em monospace caixa-alta — o "cabeçalho técnico" usado nas
/// telas de detalhe (OEE, gráfico, etc.).
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontFamily: 'monospace',
        fontSize: 11,
        color: AppTheme.textSecondary,
        letterSpacing: 1.5,
      ),
    );
  }
}

/// Ponto colorido de status, com brilho opcional quando a máquina está online.
class StatusDot extends StatelessWidget {
  const StatusDot({super.key, required this.color, this.glow = true, this.size = 10});

  final Color color;
  final bool glow;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        boxShadow: glow
            ? [BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 6)]
            : null,
      ),
    );
  }
}
