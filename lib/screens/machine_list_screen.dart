import 'dart:async';
import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/data_sources.dart';
import '../services/storage/storage_service.dart';
import '../core/theme/app_theme.dart';
import '../app/app_config.dart';
import '../widgets/section_label.dart';
import 'login_screen.dart';
import 'add_machine_screen.dart';
import 'monitor/monitor_detail_screen.dart';
import 'tex/tex_console_screen.dart';

/// Lista central de máquinas cadastradas.
///
/// Faz polling em segundo plano apenas das máquinas tipo *monitor* (as TEX são
/// HMIs ao vivo, abertas sob demanda no console). Ao tocar num item, encaminha
/// para a tela de detalhe correta conforme o [MachineType].
class MachineListScreen extends StatefulWidget {
  const MachineListScreen({super.key, required this.user});

  final AppUser user;

  @override
  State<MachineListScreen> createState() => _MachineListScreenState();
}

class _MachineListScreenState extends State<MachineListScreen>
    with WidgetsBindingObserver {
  static const _config = AppConfig();

  List<Machine> _machines = [];
  bool _loading = false;
  bool _refreshing = false;
  Timer? _timer;

  // Máquinas de exemplo no primeiro acesso — incluem uma bancada TEX.
  static List<Machine> get _demo => const [
        Machine(id: 'm1', nome: 'Torno CNC-01', ip: '192.168.1.10'),
        Machine(id: 'm2', nome: 'Fresadora FR-02', ip: '192.168.1.11'),
        Machine(
            id: 'm3',
            nome: 'Bancada TEX-01',
            ip: '192.168.1.20',
            type: MachineType.tex),
      ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
    WidgetsBinding.instance.addPostFrameCallback((_) => _greet());
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _startPolling();
    } else if (state == AppLifecycleState.paused) {
      _timer?.cancel();
    }
  }

  void _greet() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Conectado como ${widget.user.levelLabel}',
          style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
        ),
        backgroundColor: AppTheme.surfaceCard,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: const BorderSide(color: AppTheme.border),
        ),
        duration: const Duration(seconds: 3),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  void _startPolling() {
    _timer?.cancel();
    _timer = Timer.periodic(_config.listPollInterval, (_) => _pollSilent());
  }

  /// Atualiza apenas as máquinas tipo monitor, preservando a posição de cada
  /// uma na lista. As TEX permanecem intactas (não têm polling de lista).
  Future<List<Machine>> _refreshMonitors(List<Machine> source) async {
    final monitors =
        source.where((m) => m.type == MachineType.monitor).toList();
    if (monitors.isEmpty) return source;

    final updated = await AppDataSource.machines.fetchAll(monitors);
    final byId = {for (final m in updated) m.id: m};
    return [for (final m in source) byId[m.id] ?? m];
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    var saved = await StorageService.loadMachines();
    if (saved.isEmpty) saved = _demo;
    final updated = await _refreshMonitors(saved);
    if (!mounted) return;
    setState(() {
      _machines = updated;
      _loading = false;
    });
    _startPolling();
  }

  Future<void> _pollSilent() async {
    if (_refreshing || _machines.isEmpty) return;
    _refreshing = true;
    try {
      final updated = await _refreshMonitors(_machines);
      if (!mounted) return;
      setState(() => _machines = updated);
    } finally {
      _refreshing = false;
    }
  }

  Future<void> _refresh() => _pollSilent();

  Future<void> _addMachine() async {
    final result = await Navigator.push<Machine>(
      context,
      MaterialPageRoute(
        builder: (_) => AddMachineScreen(existing: _machines),
      ),
    );
    if (result == null) return;
    final list = [..._machines, result];
    await StorageService.saveMachines(list);
    final updated = await _refreshMonitors(list);
    if (!mounted) return;
    setState(() => _machines = updated);
  }

  Future<void> _remove(Machine m) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.surfaceCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Remover máquina',
            style: TextStyle(color: AppTheme.textPrimary)),
        content: Text('Remover "${m.nome}"?',
            style: const TextStyle(color: AppTheme.textSecondary)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Remover',
                  style: TextStyle(color: AppTheme.danger))),
        ],
      ),
    );
    if (ok != true) return;
    final list = _machines.where((x) => x.id != m.id).toList();
    await StorageService.saveMachines(list);
    if (!mounted) return;
    setState(() => _machines = list);
  }

  Future<void> _logout() async {
    _timer?.cancel();
    await StorageService.clearSession();
    if (!mounted) return;
    Navigator.pushReplacement(
        context, MaterialPageRoute(builder: (_) => const LoginScreen()));
  }

  /// Encaminha para a tela de detalhe conforme o tipo da máquina.
  ///
  /// É aqui que um novo [MachineType] passa a ter tela própria — basta
  /// acrescentar o `case`.
  void _openMachine(Machine m) {
    _timer?.cancel(); // pausa o polling enquanto navega
    final Widget screen;
    switch (m.type) {
      case MachineType.monitor:
        screen = MonitorDetailScreen(machine: m);
        break;
      case MachineType.tex:
        screen = TexConsoleScreen(machine: m);
        break;
    }
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen))
        .then((_) {
      if (mounted) _startPolling();
    });
  }

  int get _emCiclo => _machines
      .where((m) => m.type == MachineType.monitor && m.status == MachineStatus.emCiclo)
      .length;

  int get _monitorCount =>
      _machines.where((m) => m.type == MachineType.monitor).length;

  int get _semComunicacao => _machines.where((m) => m.semComunicacao).length;

  @override
  Widget build(BuildContext context) {
    final tablet = AppTheme.isTablet(context);
    final hPad = AppTheme.hPad(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('MÁQUINAS'),
        actions: [
          if (_refreshing)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: Center(
                child: SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                      strokeWidth: 1.5, color: AppTheme.accent),
                ),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppTheme.accent),
            onPressed: _refresh,
            tooltip: 'Atualizar agora',
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: AppTheme.textSecondary),
            onPressed: _logout,
            tooltip: 'Sair',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addMachine,
        backgroundColor: AppTheme.primary,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Nova máquina'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.accent))
          : Column(
              children: [
                _Header(
                    user: widget.user,
                    monitorTotal: _monitorCount,
                    emCiclo: _emCiclo),
                if (_semComunicacao > 0) _NetworkBanner(count: _semComunicacao),
                Expanded(
                  child: _machines.isEmpty
                      ? _Empty(onAdd: _addMachine)
                      : RefreshIndicator(
                          onRefresh: _refresh,
                          color: AppTheme.accent,
                          child: tablet
                              ? GridView.builder(
                                  padding:
                                      EdgeInsets.fromLTRB(hPad, 20, hPad, 100),
                                  gridDelegate:
                                      const SliverGridDelegateWithMaxCrossAxisExtent(
                                    maxCrossAxisExtent: 360,
                                    crossAxisSpacing: 16,
                                    mainAxisSpacing: 12,
                                    mainAxisExtent: 92,
                                  ),
                                  itemCount: _machines.length,
                                  itemBuilder: (_, i) => _MachineCard(
                                    machine: _machines[i],
                                    onTap: () => _openMachine(_machines[i]),
                                    onRemove: () => _remove(_machines[i]),
                                  ),
                                )
                              : ListView.separated(
                                  padding:
                                      EdgeInsets.fromLTRB(hPad, 20, hPad, 100),
                                  itemCount: _machines.length,
                                  separatorBuilder: (_, __) =>
                                      const SizedBox(height: 12),
                                  itemBuilder: (_, i) => _MachineCard(
                                    machine: _machines[i],
                                    onTap: () => _openMachine(_machines[i]),
                                    onRemove: () => _remove(_machines[i]),
                                  ),
                                ),
                        ),
                ),
              ],
            ),
    );
  }
}

// ─── Header ───────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  const _Header(
      {required this.user, required this.monitorTotal, required this.emCiclo});

  final AppUser user;
  final int monitorTotal, emCiclo;

  @override
  Widget build(BuildContext context) {
    final hPad = AppTheme.hPad(context);
    return Container(
      padding: EdgeInsets.fromLTRB(hPad, 16, hPad, 16),
      decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppTheme.border))),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Olá, ${user.firstName}',
                    style: const TextStyle(
                        fontSize: 15,
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.w600)),
                Text(user.levelLabel,
                    style: const TextStyle(
                        fontSize: 12, color: AppTheme.textSecondary)),
              ],
            ),
          ),
          _Chip(label: 'Monitores', value: '$monitorTotal', color: AppTheme.textSecondary),
          const SizedBox(width: 8),
          _Chip(label: 'Em Ciclo', value: '$emCiclo', color: AppTheme.success),
          const SizedBox(width: 8),
          _Chip(
              label: 'Paradas',
              value: '${monitorTotal - emCiclo}',
              color: AppTheme.danger),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.value, required this.color});

  final String label, value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Text(value,
              style: TextStyle(
                  fontSize: 17, fontWeight: FontWeight.w700, color: color)),
          Text(label,
              style: TextStyle(fontSize: 10, color: color.withValues(alpha: 0.8))),
        ],
      ),
    );
  }
}

// ─── Banner de rede ───────────────────────────────────────────────────────────

class _NetworkBanner extends StatelessWidget {
  const _NetworkBanner({required this.count});
  final int count;

  @override
  Widget build(BuildContext context) {
    final hPad = AppTheme.hPad(context);
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: hPad, vertical: 10),
      color: AppTheme.warning.withValues(alpha: 0.12),
      child: Row(
        children: [
          const Icon(Icons.wifi_off_rounded, size: 16, color: AppTheme.warning),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              count == 1
                  ? '1 máquina sem comunicação — verifique a rede das máquinas'
                  : '$count máquinas sem comunicação — verifique a rede das máquinas',
              style: const TextStyle(fontSize: 12, color: AppTheme.warning),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Card de máquina ──────────────────────────────────────────────────────────

class _MachineCard extends StatelessWidget {
  const _MachineCard(
      {required this.machine, required this.onTap, required this.onRemove});

  final Machine machine;
  final VoidCallback onTap, onRemove;

  bool get _isTex => machine.type == MachineType.tex;

  // Cor do indicador de status. TEX não faz polling de lista, então fica neutro.
  Color get _dotColor {
    if (_isTex) return AppTheme.accent;
    if (machine.semComunicacao) return AppTheme.textSecondary;
    switch (machine.status) {
      case MachineStatus.emCiclo:
        return AppTheme.success;
      case MachineStatus.parada:
        return AppTheme.danger;
      case MachineStatus.manutencao:
        return AppTheme.warning;
    }
  }

  @override
  Widget build(BuildContext context) {
    final semComun = !_isTex && machine.semComunicacao;

    return Card(
      shape: semComun
          ? RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTheme.radius),
              side: BorderSide(color: AppTheme.warning.withValues(alpha: 0.4)),
            )
          : null,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          child: Row(
            children: [
              StatusDot(color: _dotColor, glow: !semComun),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            machine.nome,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: semComun
                                  ? AppTheme.textSecondary
                                  : AppTheme.textPrimary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        _TypeBadge(type: machine.type),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(children: [
                      Icon(
                        semComun ? Icons.wifi_off_rounded : Icons.router_outlined,
                        size: 12,
                        color:
                            semComun ? AppTheme.warning : AppTheme.textSecondary,
                      ),
                      const SizedBox(width: 4),
                      Text(machine.ip,
                          style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 12,
                              color: AppTheme.textSecondary)),
                      const SizedBox(width: 10),
                      Text(
                        _isTex
                            ? 'Console'
                            : (semComun ? 'Sem comunicação' : machine.statusLabel),
                        style: TextStyle(
                          fontSize: 12,
                          color: semComun ? AppTheme.warning : _dotColor,
                        ),
                      ),
                    ]),
                  ],
                ),
              ),
              if (!_isTex)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      semComun ? '—' : '${machine.producaoDia}',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: semComun
                            ? AppTheme.textSecondary
                            : AppTheme.textPrimary,
                        fontFamily: 'monospace',
                      ),
                    ),
                    const Text('pç/dia',
                        style: TextStyle(
                            fontSize: 11, color: AppTheme.textSecondary)),
                  ],
                )
              else
                const SizedBox.shrink(),
              const SizedBox(width: 4),
              PopupMenuButton<String>(
                color: AppTheme.surfaceElevated,
                icon: const Icon(Icons.more_vert,
                    color: AppTheme.textSecondary, size: 18),
                onSelected: (v) {
                  if (v == 'remove') onRemove();
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(
                    value: 'remove',
                    child: Row(children: [
                      Icon(Icons.delete_outline, color: AppTheme.danger, size: 18),
                      SizedBox(width: 8),
                      Text('Remover', style: TextStyle(color: AppTheme.danger)),
                    ]),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Etiqueta colorida do tipo da máquina (Monitor / TEX).
class _TypeBadge extends StatelessWidget {
  const _TypeBadge({required this.type});
  final MachineType type;

  @override
  Widget build(BuildContext context) {
    final isTex = type == MachineType.tex;
    final color = isTex ? AppTheme.readout : AppTheme.accent;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        type.shortLabel,
        style: TextStyle(
          fontSize: 9,
          fontFamily: 'monospace',
          fontWeight: FontWeight.w700,
          color: color,
          letterSpacing: 1,
        ),
      ),
    );
  }
}

// ─── Estado vazio ─────────────────────────────────────────────────────────────

class _Empty extends StatelessWidget {
  const _Empty({required this.onAdd});
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.precision_manufacturing_outlined,
              size: 72, color: AppTheme.border),
          const SizedBox(height: 20),
          const Text('Nenhuma máquina cadastrada',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 16)),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Adicionar máquina'),
            style: ElevatedButton.styleFrom(minimumSize: const Size(220, 50)),
          ),
        ],
      ),
    );
  }
}