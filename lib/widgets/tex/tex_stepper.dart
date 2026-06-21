import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

/// Seletor numérico no estilo HMI: rótulo, valor grande monoespaçado e botões
/// `−` / `+` para ajustar. Usado no painel de setup da TEX (BCD, câmara,
/// testes por câmara).
///
/// O [accent] permite distinguir um seletor que escreve no CLP (ex.: BCD) dos
/// que são apenas configuração local. Mantê-lo coeso evita repetir o mesmo
/// layout de botão em cada controle.
class TexStepper extends StatelessWidget {
  const TexStepper({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.min = 0,
    this.max = 999,
    this.accent,
    this.suffix,
    this.hint,
    this.valuePrefix = '',
  });

  final String label;
  final int value;
  final ValueChanged<int> onChanged;
  final int min;
  final int max;
  final Color? accent;

  /// Texto pequeno após o valor (ex.: "testes").
  final String? suffix;

  /// Linha auxiliar abaixo do rótulo (ex.: "envia ao CLP").
  final String? hint;

  /// Prefixo do valor exibido (ex.: "Nº ").
  final String valuePrefix;

  bool get _canDec => value > min;
  bool get _canInc => value < max;

  @override
  Widget build(BuildContext context) {
    final color = accent ?? AppTheme.accent;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
          if (hint != null) ...[
            const SizedBox(height: 2),
            Text(
              hint!,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: color.withValues(alpha: 0.9),
                fontSize: 9.5,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
          ],
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _StepButton(
                icon: Icons.remove_rounded,
                color: color,
                enabled: _canDec,
                onTap: () => onChanged(value - 1),
              ),
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        '$valuePrefix$value',
                        style: TextStyle(
                          color: color,
                          fontSize: 34,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'monospace',
                          height: 1.0,
                        ),
                      ),
                      if (suffix != null) ...[
                        const SizedBox(width: 6),
                        Text(
                          suffix!,
                          style: const TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              _StepButton(
                icon: Icons.add_rounded,
                color: color,
                enabled: _canInc,
                onTap: () => onChanged(value + 1),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({
    required this.icon,
    required this.color,
    required this.enabled,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = enabled ? color : AppTheme.textMuted.withValues(alpha: 0.4);
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
      child: Container(
        width: 40,
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: enabled
              ? color.withValues(alpha: 0.12)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
          border: Border.all(color: c.withValues(alpha: 0.6)),
        ),
        child: Icon(icon, color: c, size: 22),
      ),
    );
  }
}
