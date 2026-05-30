import 'package:flutter/material.dart';
import '../../models/tex_models.dart';
import '../../services/data_sources.dart';
import '../../core/theme/app_theme.dart';
import '../../widgets/tex/tex_panel.dart';
import '../../widgets/tex/value_readout.dart';
import '../../widgets/tex/tex_action_button.dart';

/// Tela principal do console TEX: navegação de câmara, barra de progresso,
/// leituras de pressão e vazamento e os botões de comando.
///
/// Recebe um [TexSnapshot] (estado) e a [TexSession] (para disparar comandos).
/// O layout adapta-se: lado a lado em telas largas, empilhado em telas
/// estreitas — ao contrário do original, que assumia paisagem fixa.
class OperationView extends StatelessWidget {
  const OperationView({super.key, required this.snapshot, required this.session});

  final TexSnapshot snapshot;
  final TexSession session;

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 520;

    final readouts = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _CameraNav(snapshot: snapshot, session: session),
        const SizedBox(height: 10),
        _StatusRow(snapshot: snapshot),
        const SizedBox(height: 10),
        Expanded(
          child: ValueReadout(
            title: 'PRESSÃO ATUAL',
            value: snapshot.pressao,
            unit: snapshot.pressaoUnit,
          ),
        ),
        const SizedBox(height: 10),
        Expanded(
          child: ValueReadout(
            title: 'VAZAMENTO',
            value: snapshot.vazamento,
            unit: snapshot.vazamentoUnit,
          ),
        ),
      ],
    );

    return Padding(
      padding: const EdgeInsets.all(12),
      child: wide
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: readouts),
                const SizedBox(width: 12),
                SizedBox(
                    width: 116,
                    child: _ActionButtons(snapshot: snapshot, session: session)),
              ],
            )
          : Column(
              children: [
                Expanded(child: readouts),
                const SizedBox(height: 12),
                _ActionButtonsRow(snapshot: snapshot, session: session),
              ],
            ),
    );
  }
}

// ─── Navegação de câmara ──────────────────────────────────────────────────────

class _CameraNav extends StatelessWidget {
  const _CameraNav({required this.snapshot, required this.session});

  final TexSnapshot snapshot;
  final TexSession session;

  @override
  Widget build(BuildContext context) {
    return TexPanel(
      child: SizedBox(
        height: 56,
        child: Row(
          children: [
            _ArrowButton(
                icon: Icons.chevron_left_rounded, onTap: session.prevCamera),
            Expanded(
              child: Center(
                child: RichText(
                  textAlign: TextAlign.center,
                  text: TextSpan(
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold),
                    children: [
                      TextSpan(
                          text: snapshot.programName,
                          style: const TextStyle(color: AppTheme.textPrimary)),
                      const TextSpan(text: '   '),
                      TextSpan(
                        text:
                            'CÂMARA ${snapshot.cameraNumber}/${snapshot.totalCameras}',
                        style: const TextStyle(
                            color: AppTheme.textSecondary, fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            _ArrowButton(
                icon: Icons.chevron_right_rounded, onTap: session.nextCamera),
          ],
        ),
      ),
    );
  }
}

class _ArrowButton extends StatelessWidget {
  const _ArrowButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
      child: Container(
        width: 52,
        height: 56,
        alignment: Alignment.center,
        child: Icon(icon, color: AppTheme.textPrimary, size: 30),
      ),
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
    final showSpinner =
        running && snapshot.phase != TexPhase.resultado;

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
    return Row(
      children: [
        Expanded(
          child: TexActionButton(
            icon: Icons.play_arrow_rounded,
            label: 'START',
            onTap: session.start,
            color: snapshot.running ? AppTheme.success : null,
            active: snapshot.running,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: TexActionButton(
            icon: Icons.stop_rounded,
            label: 'STOP',
            onTap: session.stop,
            color: snapshot.running
                ? AppTheme.danger
                : AppTheme.danger.withValues(alpha: 0.45),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: TexActionButton(
            icon: Icons.block_rounded,
            label: 'BLOQUEIO',
            onTap: session.toggleEscapeBlock,
            color: snapshot.escapeBloqueado ? AppTheme.danger : null,
            active: snapshot.escapeBloqueado,
          ),
        ),
      ],
    );
  }
}
