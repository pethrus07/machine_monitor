import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

/// LED redondo aceso/apagado, com brilho quando ativo.
///
/// É a peça visual repetida nas linhas de E-S e de diagnóstico. A cor do
/// estado "aceso" é parametrizável porque o diagnóstico acende em vermelho
/// (erro) e a E-S em verde (sinal presente).
class LedIndicator extends StatelessWidget {
  const LedIndicator({
    super.key,
    required this.on,
    this.onColor = AppTheme.ledOn,
    this.size = 20,
  });

  final bool on;
  final Color onColor;
  final double size;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: on ? onColor : AppTheme.ledOff,
        border: Border.all(
          color: on ? onColor.withValues(alpha: 0.6) : AppTheme.border,
          width: 2,
        ),
        boxShadow: on
            ? [BoxShadow(color: onColor.withValues(alpha: 0.5), blurRadius: 8, spreadRadius: 1)]
            : null,
      ),
    );
  }
}

/// Linha "LED + texto" das listas de E-S e diagnóstico.
///
/// Quando [on] é verdadeiro o texto ganha destaque (cor/peso). O [trailing]
/// opcional acomoda o ícone de alerta usado no diagnóstico.
class LedRow extends StatelessWidget {
  const LedRow({
    super.key,
    required this.on,
    required this.label,
    this.onColor = AppTheme.ledOn,
    this.trailing,
  });

  final bool on;
  final String label;
  final Color onColor;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          LedIndicator(on: on, onColor: onColor),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: on ? AppTheme.textPrimary : AppTheme.textSecondary,
                fontSize: 14,
                fontWeight: on ? FontWeight.w600 : FontWeight.normal,
                letterSpacing: 0.3,
              ),
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}
