import 'dart:async';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../models/models.dart';
import '../../services/data_sources.dart';
import '../../core/theme/app_theme.dart';
import '../../app/app_config.dart';
import '../../widgets/section_label.dart';
import '../../widgets/info_tile.dart';

/// Detalhe de uma máquina tipo *monitor*: status, OEE, produção e gráfico por
/// hora. Faz polling pontual via [AppDataSource.machines] enquanto a tela está
/// aberta (pausando quando o app vai para segundo plano).
class MonitorDetailScreen extends StatefulWidget {
  const MonitorDetailScreen({super.key, required this.machine});

  final Machine machine;

  @override
  State<MonitorDetailScreen> createState() => _MonitorDetailScreenState();
}

class _MonitorDetailScreenState extends State<MonitorDetailScreen>
    with WidgetsBindingObserver {
  static const _config = AppConfig();

  late Machine _m;
  bool _loading = false;
  bool _polling = false;
  Timer? _timer;
  DateTime? _lastUpdate;

  @override
  void initState() {
    super.initState();
    _m = widget.machine;
    WidgetsBinding.instance.addObserver(this);
    _startPolling();
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

  void _startPolling() {
    _timer?.cancel();
    _pollSilent(); // busca imediatamente ao abrir
    _timer = Timer.periodic(_config.detailPollInterval, (_) => _pollSilent());
  }

  Future<void> _pollSilent() async {
    if (_polling) return; // ignora se o request anterior ainda não terminou
    _polling = true;
    try {
      final updated = await AppDataSource.machines.fetchMachineData(_m);
      if (!mounted) return;
      setState(() {
        _m = updated;
        _lastUpdate = DateTime.now();
      });
    } finally {
      _polling = false;
    }
  }

  Future<void> _refresh() async {
    setState(() => _loading = true);
    await _pollSilent();
    if (mounted) setState(() => _loading = false);
  }

  Color get _statusColor {
    if (_m.semComunicacao) return AppTheme.warning;
    switch (_m.status) {
      case MachineStatus.emCiclo:
        return AppTheme.success;
      case MachineStatus.parada:
        return AppTheme.danger;
      case MachineStatus.manutencao:
        return AppTheme.warning;
    }
  }

  String get _lastUpdateLabel {
    if (_lastUpdate == null) return '';
    final diff = DateTime.now().difference(_lastUpdate!);
    if (diff.inSeconds < 5) return 'agora';
    if (diff.inSeconds < 60) return 'há ${diff.inSeconds}s';
    return 'há ${diff.inMinutes}min';
  }

  @override
  Widget build(BuildContext context) {
    final tablet = AppTheme.isTablet(context);
    final hPad = AppTheme.hPad(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(_m.nome.toUpperCase()),
        actions: [
          if (_polling)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 4),
              child: Center(
                child: SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                      strokeWidth: 1.5, color: AppTheme.accent),
                ),
              ),
            ),
          if (_lastUpdate != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Center(
                child: Text(_lastUpdateLabel,
                    style: const TextStyle(
                        fontSize: 11, color: AppTheme.textSecondary)),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppTheme.accent),
            onPressed: _refresh,
            tooltip: 'Atualizar agora',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.accent))
          : RefreshIndicator(
              onRefresh: _refresh,
              color: AppTheme.accent,
              child: ListView(
                padding: EdgeInsets.fromLTRB(hPad, 20, hPad, 40),
                children: [
                  if (_m.semComunicacao) ...[
                    _SemComunicacaoBanner(ip: _m.ip),
                    const SizedBox(height: 16),
                  ],
                  if (tablet) ...[
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                            child: _StatusCard(m: _m, statusColor: _statusColor)),
                        const SizedBox(width: 16),
                        Expanded(child: _ProdCard(m: _m)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _OEESection(oee: _m.oee),
                    if (_m.producaoPorHora.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      _HourlyChart(horas: _m.producaoPorHora),
                    ],
                  ] else ...[
                    _StatusCard(m: _m, statusColor: _statusColor),
                    const SizedBox(height: 16),
                    _OEESection(oee: _m.oee),
                    const SizedBox(height: 16),
                    _ProdCard(m: _m),
                    if (_m.producaoPorHora.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      _HourlyChart(horas: _m.producaoPorHora),
                    ],
                  ],
                ],
              ),
            ),
    );
  }
}

// ─── Banner sem comunicação ───────────────────────────────────────────────────

class _SemComunicacaoBanner extends StatelessWidget {
  const _SemComunicacaoBanner({required this.ip});
  final String ip;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppTheme.warning.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(color: AppTheme.warning.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.wifi_off_rounded, color: AppTheme.warning, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Sem comunicação',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.warning)),
                const SizedBox(height: 4),
                Text(
                  'Não foi possível conectar ao CLP em $ip.\n'
                  'Verifique se o dispositivo está na rede das máquinas e se o '
                  'endereço IP está correto.',
                  style: const TextStyle(
                      fontSize: 12, color: AppTheme.textSecondary),
                ),
                const SizedBox(height: 8),
                const Text('Os dados exibidos são do último ciclo bem-sucedido.',
                    style: TextStyle(
                        fontSize: 11,
                        color: AppTheme.textSecondary,
                        fontStyle: FontStyle.italic)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Card de status ───────────────────────────────────────────────────────────

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.m, required this.statusColor});

  final Machine m;
  final Color statusColor;

  IconData get _icon {
    if (m.semComunicacao) return Icons.wifi_off_rounded;
    switch (m.status) {
      case MachineStatus.emCiclo:
        return Icons.settings_outlined;
      case MachineStatus.parada:
        return Icons.pause_circle_outline;
      case MachineStatus.manutencao:
        return Icons.build_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(AppTheme.cardPad(context)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppTheme.radius),
                    border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                  ),
                  child: Icon(_icon, color: statusColor, size: 26),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        m.semComunicacao
                            ? 'SEM COMUNICAÇÃO'
                            : m.statusLabel.toUpperCase(),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: m.semComunicacao
                              ? AppTheme.warning
                              : statusColor,
                          letterSpacing: 1,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Row(children: [
                        Icon(
                          m.semComunicacao
                              ? Icons.wifi_off_rounded
                              : Icons.router_outlined,
                          size: 12,
                          color: m.semComunicacao
                              ? AppTheme.warning
                              : AppTheme.textSecondary,
                        ),
                        const SizedBox(width: 4),
                        Text(m.ip,
                            style: const TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 12,
                                color: AppTheme.textSecondary)),
                      ]),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            const Divider(height: 1),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: InfoTile(
                    icon: Icons.inventory_2_outlined,
                    label: 'Produto Atual',
                    value: m.produtoAtual,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: InfoTile(
                    icon: Icons.person_outline_rounded,
                    label: 'Operador',
                    value: m.operador,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Seção de OEE ─────────────────────────────────────────────────────────────

class _OEESection extends StatelessWidget {
  const _OEESection({required this.oee});
  final OEEData oee;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 4, bottom: 10),
          child: SectionLabel('OEE – EFICIÊNCIA GLOBAL'),
        ),
        Row(children: [
          Expanded(
              child: _OEECard(
                  label: 'OEE Geral', value: oee.oeeGeral, highlight: true)),
          const SizedBox(width: 10),
          Expanded(
              child:
                  _OEECard(label: 'Disponib.', value: oee.disponibilidade)),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: _OEECard(label: 'Performance', value: oee.performance)),
          const SizedBox(width: 10),
          Expanded(child: _OEECard(label: 'Qualidade', value: oee.qualidade)),
        ]),
      ],
    );
  }
}

class _OEECard extends StatelessWidget {
  const _OEECard(
      {required this.label, required this.value, this.highlight = false});

  final String label;
  final double value;
  final bool highlight;

  Color get _vc {
    if (value >= 85) return AppTheme.success;
    if (value >= 60) return AppTheme.warning;
    return AppTheme.danger;
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: highlight
          ? RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTheme.radius),
              side: BorderSide(color: _vc.withValues(alpha: 0.4)),
            )
          : null,
      child: Padding(
        padding: EdgeInsets.symmetric(
            horizontal: AppTheme.cardPad(context), vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: const TextStyle(
                    fontSize: 11, color: AppTheme.textSecondary)),
            const SizedBox(height: 6),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  value.toStringAsFixed(1),
                  style: TextStyle(
                    fontSize: highlight ? 28 : 22,
                    fontWeight: FontWeight.w700,
                    color: _vc,
                    fontFamily: 'monospace',
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.only(bottom: 3, left: 2),
                  child: Text('%',
                      style: TextStyle(
                          fontSize: 13, color: AppTheme.textSecondary)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: value / 100,
                backgroundColor: AppTheme.border,
                valueColor: AlwaysStoppedAnimation<Color>(_vc),
                minHeight: 5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Card de produção ─────────────────────────────────────────────────────────

class _ProdCard extends StatelessWidget {
  const _ProdCard({required this.m});
  final Machine m;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: EdgeInsets.symmetric(
            horizontal: AppTheme.cardPad(context), vertical: 20),
        child: Row(
          children: [
            Expanded(
              child: _ProdStat(
                  label: 'Produção no Dia',
                  value: '${m.producaoDia}',
                  unit: 'peças/dia',
                  color: AppTheme.accent),
            ),
            Container(width: 1, height: 52, color: AppTheme.border),
            Expanded(
              child: _ProdStat(
                  label: 'Produção Atual',
                  value: '${m.producaoAtual}',
                  unit: 'peças/ciclo',
                  color: AppTheme.textPrimary),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProdStat extends StatelessWidget {
  const _ProdStat(
      {required this.label,
      required this.value,
      required this.unit,
      required this.color});

  final String label, value, unit;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final tablet = AppTheme.isTablet(context);
    return Column(
      children: [
        Text(label,
            style:
                const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
        const SizedBox(height: 8),
        Text(value,
            style: TextStyle(
                fontSize: tablet ? 32 : 28,
                fontWeight: FontWeight.w700,
                color: color,
                fontFamily: 'monospace')),
        const SizedBox(height: 2),
        Text(unit,
            style:
                const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
      ],
    );
  }
}

// ─── Gráfico de produção por hora ────────────────────────────────────────────

class _HourlyChart extends StatelessWidget {
  const _HourlyChart({required this.horas});
  final List<ProducaoHora> horas;

  @override
  Widget build(BuildContext context) {
    final tablet = AppTheme.isTablet(context);
    final barWidth = tablet ? 22.0 : 14.0;
    final chartH = tablet ? 220.0 : 180.0;

    return Card(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
            AppTheme.cardPad(context), 20, AppTheme.cardPad(context), 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionLabel('PRODUÇÃO POR HORA – TURNO CORRENTE'),
            const SizedBox(height: 20),
            SizedBox(
              height: chartH,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: _calcMaxY(),
                  barTouchData: BarTouchData(
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipColor: (_) => AppTheme.surfaceElevated,
                      getTooltipItem: (group, gi, rod, _) {
                        final h = horas[gi];
                        return BarTooltipItem(
                          '${h.hora.toString().padLeft(2, '0')}h\n${h.producao} pç',
                          const TextStyle(
                              color: AppTheme.textPrimary, fontSize: 12),
                        );
                      },
                    ),
                  ),
                  titlesData: FlTitlesData(
                    show: true,
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 28,
                        getTitlesWidget: (v, _) {
                          final i = v.toInt();
                          if (i < 0 || i >= horas.length) {
                            return const SizedBox.shrink();
                          }
                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              '${horas[i].hora.toString().padLeft(2, '0')}h',
                              style: const TextStyle(
                                  fontSize: 10, color: AppTheme.textSecondary),
                            ),
                          );
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                        getTitlesWidget: (v, _) => Text(
                          '${v.toInt()}',
                          style: const TextStyle(
                              fontSize: 10, color: AppTheme.textSecondary),
                        ),
                      ),
                    ),
                    rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                  ),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (_) =>
                        const FlLine(color: AppTheme.border, strokeWidth: 0.5),
                  ),
                  borderData: FlBorderData(show: false),
                  barGroups: [
                    for (int i = 0; i < horas.length; i++)
                      BarChartGroupData(
                        x: i,
                        barRods: [
                          BarChartRodData(
                            toY: horas[i].producao.toDouble(),
                            width: barWidth,
                            borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(4)),
                            gradient: const LinearGradient(
                              colors: [AppTheme.accent, AppTheme.accentSoft],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: AppTheme.accent,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                const SizedBox(width: 6),
                const Text('Peças produzidas',
                    style:
                        TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  double _calcMaxY() {
    if (horas.isEmpty) return 100;
    final max = horas.map((h) => h.producao).reduce((a, b) => a > b ? a : b);
    // Arredonda para cima em múltiplos de 20 e adiciona 20% de folga.
    final top = ((max * 1.2) / 20).ceil() * 20;
    return top.toDouble().clamp(40, double.infinity);
  }
}
