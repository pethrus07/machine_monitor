import 'package:flutter/material.dart';
import '../../models/tex_models.dart';
import '../../models/tex_setup.dart';
import '../../services/data_sources.dart';
import '../../core/theme/app_theme.dart';
import '../../widgets/tex/tex_stepper.dart';
import '../../widgets/tex/value_readout.dart';
import '../../widgets/tex/tex_action_button.dart';

/// Tela principal do console TEX: leituras de pressão/vazamento, status do
/// ciclo, o painel de setup (BCD / câmara / testes por câmara) e os botões de
/// comando.
///
/// O BCD é escrito no CLP ([onBcd]); câmara e testes por câmara são
/// configuração local da máquina ([onChamber], [onTests]). O layout adapta-se:
/// painel de comando à direita em telas largas, empilhado em telas estreitas.
class OperationView extends StatelessWidget {
  const OperationView({
    super.key,
    required this.snapshot,
    required this.session,
    required this.setup,
    required this.onBcd,
    required this.onChamber,
    required this.onTests,
  });

  final TexSnapshot snapshot;
  final TexSession session;
  final TexSetup setup;
  final ValueChanged<int> onBcd;
  final ValueChanged<int> onChamber;
  final ValueChanged<int> onTests;

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 520;

    final readouts = Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: ValueReadout(
            title: 'PRESSÃO ATUAL',
            value: snapshot.pressao,
            unit: snapshot.pressaoUnit,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: ValueReadout(
            title: 'VAZAMENTO',
            value: snapshot.vazamento,
            unit: snapshot.vazamentoUnit,
          ),
        ),
      ],
    );

    final leftColumn = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _StatusRow(snapshot: snapshot),
        const SizedBox(height: 10),
        Expanded(child: readouts),
        const SizedBox(height: 10),
        _SetupPanel(
          setup: setup,
          wide: wide,
          onBcd: onBcd,
          onChamber: onChamber,
          onTests: onTests,
        ),
      ],
    );

    return Padding(
      padding: const EdgeInsets.all(12),
      child: wide
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: leftColumn),
                const SizedBox(width: 12),
                SizedBox(
                  width: 132,
                  child: _ActionButtons(snapshot: snapshot, session: session),
                ),
              ],
            )
          : Column(
              children: [
                Expanded(child: leftColumn),
                const SizedBox(height: 12),
                _ActionButtonsRow(snapshot: snapshot, session: session),
              ],
            ),
    );
  }
}

// ─── Painel de setup (BCD / câmara / testes) ──────────────────────────────────

class _SetupPanel extends StatelessWidget {
  const _SetupPanel({
    required this.setup,
    required this.wide,
    required this.onBcd,
    required this.onChamber,
    required this.onTests,
  });

  final TexSetup setup;
  final bool wide;
  final ValueChanged<int> onBcd;
  final ValueChanged<int> onChamber;
  final ValueChanged<int> onTests;

  @override
  Widget build(BuildContext context) {
    final bcd = TexStepper(
      label: 'BCD',
      hint: 'ENVIA AO CLP',
      value: setup.bcd,
      min: 0,
      max: TexSetup.maxBcd,
      accent: AppTheme.readout,
      onChanged: onBcd,
    );

    final camara = TexStepper(
      label: 'CÂMARA',
      hint: 'LOCAL',
      value: setup.selectedChamber,
      min: 1,
      max: TexSetup.maxChambers,
      onChanged: onChamber,
    );

    final testes = TexStepper(
      label: 'TESTES / CÂMARA',
      hint: 'CÂM. ${setup.selectedChamber}',
      value: setup.currentTests,
      min: 1,
      max: TexSetup.maxTests,
      suffix: 'testes',
      onChanged: onTests,
    );

    if (wide) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: bcd),
          const SizedBox(width: 10),
          Expanded(child: camara),
          const SizedBox(width: 10),
          Expanded(child: testes),
        ],
      );
    }

    // Estreito: BCD em destaque na primeira linha, câmara + testes abaixo.
    return Column(
      children: [
        bcd,
        const SizedBox(height: 10),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: camara),
            const SizedBox(width: 10),
            Expanded(child: testes),
          ],
        ),
      ],
    );
  }
}

// ─── Linha de progresso + status ──────────────────────────────────────────────

class _StatusRow extends StatelessWidget {
  const _StatusRow({required this.snapshot});
  final TexSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final color = snapshot.statusColor;
    final running = snapshot.running;
    final showSpinner = running && snapshot.phase != TexPhase.resultado;

    return SizedBox(
      height: 40,
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Container(
              decoration: BoxDecoration(
                color: AppTheme.surfaceCard,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppTheme.border),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(5),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: FractionallySizedBox(
                    widthFactor: snapshot.progresso.clamp(0.0, 1.0),
                    child: Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(colors: [
                          AppTheme.readout,
                          AppTheme.warning,
                        ]),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 2,
            child: Container(
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: color.withValues(alpha: 0.5)),
              ),
              child: Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (showSpinner)
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: color),
                        ),
                      ),
                    Flexible(
                      child: Text(
                        showSpinner
                            ? '${snapshot.statusLabel} (${snapshot.elapsedTime.toStringAsFixed(1)}s)'
                            : snapshot.statusLabel,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: color,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Botões de comando ────────────────────────────────────────────────────────

class _ActionButtons extends StatelessWidget {
  const _ActionButtons({required this.snapshot, required this.session});

  final TexSnapshot snapshot;
  final TexSession session;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          flex: 5,
          child: TexActionButton(
            icon: Icons.play_arrow_rounded,
            label: 'START',
            onTap: session.start,
            color: snapshot.running ? AppTheme.success : null,
            active: snapshot.running,
            height: double.infinity,
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          flex: 5,
          child: TexActionButton(
            icon: Icons.stop_rounded,
            label: 'STOP',
            onTap: session.stop,
            color: snapshot.running
                ? AppTheme.danger
                : AppTheme.danger.withValues(alpha: 0.45),
            height: double.infinity,
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          flex: 3,
          child: TexActionButton(
            icon: Icons.block_rounded,
            label: 'BLOQUEIO\nESCAPE',
            onTap: session.toggleEscapeBlock,
            color: snapshot.escapeBloqueado ? AppTheme.danger : null,
            active: snapshot.escapeBloqueado,
            height: double.infinity,
          ),
        ),
      ],
    );
  }
}

/// Variante horizontal dos comandos para telas estreitas/retrato.
class _ActionButtonsRow extends StatelessWidget {
  const _ActionButtonsRow({required this.snapshot, required this.session});

  final TexSnapshot snapshot;
  final TexSession session;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 84,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            flex: 2,
            child: TexActionButton(
              icon: Icons.play_arrow_rounded,
              label: 'START',
              onTap: session.start,
              color: snapshot.running ? AppTheme.success : null,
              active: snapshot.running,
              height: double.infinity,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 2,
            child: TexActionButton(
              icon: Icons.stop_rounded,
              label: 'STOP',
              onTap: session.stop,
              color: snapshot.running
                  ? AppTheme.danger
                  : AppTheme.danger.withValues(alpha: 0.45),
              height: double.infinity,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 1,
            child: TexActionButton(
              icon: Icons.block_rounded,
              label: 'BLOQUEIO',
              onTap: session.toggleEscapeBlock,
              color: snapshot.escapeBloqueado ? AppTheme.danger : null,
              active: snapshot.escapeBloqueado,
              height: double.infinity,
            ),
          ),
        ],
      ),
    );
  }
}
