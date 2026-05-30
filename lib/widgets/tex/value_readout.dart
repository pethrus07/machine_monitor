import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import 'tex_panel.dart';

/// Leitura numérica grande (pressão, vazamento) dentro de um [TexPanel].
///
/// O número usa a cor laranja de leitura ([AppTheme.readout]) e fonte
/// monoespaçada para não "dançar" quando os dígitos mudam — comportamento
/// esperado de uma IHM industrial.
class ValueReadout extends StatelessWidget {
  const ValueReadout({
    super.key,
    required this.title,
    required this.value,
    required this.unit,
    this.fractionDigits = 3,
    this.showSign = true,
  });

  final String title;
  final double value;
  final String unit;
  final int fractionDigits;

  /// Mostra o "+" explícito em valores positivos (padrão das IHMs TEX).
  final bool showSign;

  @override
  Widget build(BuildContext context) {
    final formatted = value.toStringAsFixed(fractionDigits);
    final text = (showSign && value >= 0) ? '+$formatted' : formatted;

    return TexPanel(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 14,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 10),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.center,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  text,
                  style: const TextStyle(
                    color: AppTheme.readout,
                    fontSize: 72,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'monospace',
                    height: 1.0,
                  ),
                ),
                const SizedBox(width: 10),
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    unit,
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 24,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
