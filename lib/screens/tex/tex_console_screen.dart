import 'dart:async';
import 'package:flutter/material.dart';
import '../../models/models.dart';
import '../../models/tex_models.dart';
import '../../services/data_sources.dart';
import '../../core/theme/app_theme.dart';
import 'operation_view.dart';
import 'io_view.dart';
import 'diagnostics_view.dart';

/// Console ao vivo de uma bancada TEX.
///
/// Diferente do monitor (polling pontual), aqui abrimos uma [TexSession] que
/// publica um fluxo contínuo de [TexSnapshot]. Toda a tela é reconstruída por
/// um [ValueListenableBuilder] sobre esse fluxo — nenhum `setState` manual de
/// dados é necessário. A sessão é criada no [initState] e descartada no
/// [dispose], garantindo que timers/sockets não vazem ao sair da tela.
class TexConsoleScreen extends StatefulWidget {
  const TexConsoleScreen({super.key, required this.machine});

  final Machine machine;

  @override
  State<TexConsoleScreen> createState() => _TexConsoleScreenState();
}

class _TexConsoleScreenState extends State<TexConsoleScreen> {
  late final TexSession _session;
  int _tab = 0;

  static const _titles = ['OPERAÇÃO', 'ENTRADAS / SAÍDAS', 'DIAGNÓSTICOS'];

  @override
  void initState() {
    super.initState();
    _session = AppDataSource.tex.connect(widget.machine);
  }

  @override
  void dispose() {
    _session.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surfaceDeep,
      body: SafeArea(
        child: ValueListenableBuilder<TexSnapshot>(
          valueListenable: _session.snapshot,
          builder: (context, snap, _) {
            return Column(
              children: [
                _Header(
                  machineName: widget.machine.nome,
                  programName: snap.programName,
                  title: _titles[_tab],
                  onBack: () => Navigator.pop(context),
                ),
                Expanded(child: _buildBody(snap)),
                _AlarmBar(message: snap.alarme),
                _NavBar(
                  current: _tab,
                  onSelect: (i) => setState(() => _tab = i),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildBody(TexSnapshot snap) {
    switch (_tab) {
      case 1:
        return IoView(snapshot: snap);
      case 2:
        return DiagnosticsView(snapshot: snap);
      case 0:
      default:
        return OperationView(snapshot: snap, session: _session);
    }
  }
}

// ─── Cabeçalho ────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  const _Header({
    required this.machineName,
    required this.programName,
    required this.title,
    required this.onBack,
  });

  final String machineName;
  final String programName;
  final String title;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 520;
    return Container(
      decoration: const BoxDecoration(
        gradient: AppTheme.headerGradient,
        border: Border(bottom: BorderSide(color: AppTheme.border)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_rounded,
                color: AppTheme.textSecondary),
            onPressed: onBack,
            tooltip: 'Voltar',
          ),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                machineName,
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 2),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: AppTheme.accent),
                ),
                child: Text(
                  programName,
                  style: const TextStyle(
                    color: AppTheme.accent,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          if (wide) ...[
            const Spacer(),
            Text(
              title,
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
              ),
            ),
          ],
          const Spacer(),
          const _LiveClock(),
          const SizedBox(width: 8),
        ],
      ),
    );
  }
}

class _LiveClock extends StatefulWidget {
  const _LiveClock();

  @override
  State<_LiveClock> createState() => _LiveClockState();
}

class _LiveClockState extends State<_LiveClock> {
  Timer? _timer;
  late String _text;

  @override
  void initState() {
    super.initState();
    _text = _now();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _text = _now());
    });
  }

  String _now() {
    final n = DateTime.now();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(n.hour)}:${two(n.minute)}  ${two(n.day)}/${two(n.month)}/${n.year}';
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      _text,
      style: const TextStyle(
        color: AppTheme.textSecondary,
        fontSize: 12,
        fontFamily: 'monospace',
      ),
    );
  }
}

// ─── Barra de alarme ──────────────────────────────────────────────────────────

class _AlarmBar extends StatelessWidget {
  const _AlarmBar({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    final hasAlarm = message.isNotEmpty;
    return Container(
      height: 32,
      width: double.infinity,
      color: hasAlarm ? AppTheme.alarm : AppTheme.alarm.withValues(alpha: 0.75),
      alignment: Alignment.center,
      child: Text(
        hasAlarm ? message : 'ALARMES GERAIS DA MÁQUINA',
        style: TextStyle(
          color: Colors.white,
          fontSize: 13,
          fontWeight: FontWeight.bold,
          letterSpacing: hasAlarm ? 0.5 : 1.5,
        ),
      ),
    );
  }
}

// ─── Navegação inferior ───────────────────────────────────────────────────────

class _NavBar extends StatelessWidget {
  const _NavBar({required this.current, required this.onSelect});

  final int current;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      color: AppTheme.surface,
      child: Row(
        children: [
          _Tab(
              index: 0,
              icon: Icons.play_circle_outline,
              label: 'Operação',
              current: current,
              onSelect: onSelect),
          _Tab(
              index: 1,
              icon: Icons.swap_horiz_rounded,
              label: 'E / S',
              current: current,
              onSelect: onSelect),
          _Tab(
              index: 2,
              icon: Icons.build_circle_outlined,
              label: 'Diagnósticos',
              current: current,
              onSelect: onSelect),
        ],
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  const _Tab({
    required this.index,
    required this.icon,
    required this.label,
    required this.current,
    required this.onSelect,
  });

  final int index;
  final IconData icon;
  final String label;
  final int current;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final selected = index == current;
    final color = selected ? AppTheme.accent : AppTheme.textMuted;
    return Expanded(
      child: InkWell(
        onTap: () => onSelect(index),
        child: Container(
          decoration: BoxDecoration(
            color: selected ? AppTheme.surfaceCard : Colors.transparent,
            border: Border(
              top: BorderSide(
                color: selected ? AppTheme.accent : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 10,
                  fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
