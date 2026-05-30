import 'package:flutter/material.dart';
import '../../models/tex_models.dart';
import '../../core/theme/app_theme.dart';
import '../../widgets/tex/tex_panel.dart';
import '../../widgets/tex/led_indicator.dart';

/// Tela de Entradas e Saídas: dois painéis de LEDs lado a lado (ou empilhados
/// em telas estreitas) refletindo o estado digital lido do CLP.
class IoView extends StatelessWidget {
  const IoView({super.key, required this.snapshot});

  final TexSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 520;
    final inputs = _IoPanel(title: 'ENTRADAS', pins: snapshot.inputs);
    final outputs = _IoPanel(title: 'SAÍDAS', pins: snapshot.outputs);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: wide
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: inputs),
                const SizedBox(width: 16),
                Expanded(child: outputs),
              ],
            )
          : Column(
              children: [
                Expanded(child: inputs),
                const SizedBox(height: 16),
                Expanded(child: outputs),
              ],
            ),
    );
  }
}

class _IoPanel extends StatelessWidget {
  const _IoPanel({required this.title, required this.pins});

  final String title;
  final List<TexIoPin> pins;

  @override
  Widget build(BuildContext context) {
    return TexTitledPanel(
      title: title,
      accent: AppTheme.border,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 14),
        itemCount: pins.length,
        itemBuilder: (_, i) {
          final pin = pins[i];
          return LedRow(
            on: pin.active,
            label: '${pin.number} – ${pin.label}',
          );
        },
      ),
    );
  }
}
