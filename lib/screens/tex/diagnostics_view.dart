import 'package:flutter/material.dart';
import '../../models/tex_models.dart';
import '../../core/theme/app_theme.dart';
import '../../widgets/tex/tex_panel.dart';
import '../../widgets/tex/led_indicator.dart';

/// Tela de diagnósticos: dois painéis (AUTO CHECK e DIAGNÓSTICO) com LEDs que
/// acendem em vermelho quando há falha no item correspondente.
class DiagnosticsView extends StatelessWidget {
  const DiagnosticsView({super.key, required this.snapshot});

  final TexSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 520;
    final auto = _DiagPanel(title: 'AUTO CHECK', items: snapshot.autoCheck);
    final diag =
        _DiagPanel(title: 'DIAGNÓSTICO', items: snapshot.diagnostico);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: wide
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: auto),
                const SizedBox(width: 16),
                Expanded(child: diag),
              ],
            )
          : Column(
              children: [
                Expanded(child: auto),
                const SizedBox(height: 16),
                Expanded(child: diag),
              ],
            ),
    );
  }
}

class _DiagPanel extends StatelessWidget {
  const _DiagPanel({required this.title, required this.items});

  final String title;
  final List<TexDiagnostic> items;

  @override
  Widget build(BuildContext context) {
    return TexTitledPanel(
      title: title,
      accent: AppTheme.border,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 14),
        itemCount: items.length,
        itemBuilder: (_, i) {
          final item = items[i];
          return LedRow(
            on: item.hasError,
            onColor: AppTheme.danger,
            label: item.label,
            trailing: item.hasError
                ? const Icon(Icons.warning_amber_rounded,
                    color: AppTheme.danger, size: 18)
                : null,
          );
        },
      ),
    );
  }
}
