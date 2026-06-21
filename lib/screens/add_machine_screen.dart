import 'package:flutter/material.dart';
import '../models/models.dart';
import '../core/theme/app_theme.dart';
import '../core/utils/validators.dart';

/// Cadastro de uma nova máquina.
///
/// Mantém o cadastro propositalmente enxuto para usuários leigos: nome, tipo e
/// endereço. O **tipo** decide qual tela de detalhe abre e qual fonte de dados
/// alimenta a máquina. Parâmetros técnicos de conexão (protocolo, porta, unit
/// ID) ficam globais por enquanto e, no futuro, virão num bloco "avançado"
/// recolhido — fora do caminho de quem só quer cadastrar a máquina.
class AddMachineScreen extends StatefulWidget {
  const AddMachineScreen({super.key, this.existing = const []});

  /// Máquinas já cadastradas — usadas para sugerir o nome (TEX 1, TEX 2, …) e
  /// barrar IP duplicado.
  final List<Machine> existing;

  @override
  State<AddMachineScreen> createState() => _AddMachineScreenState();
}

class _AddMachineScreenState extends State<AddMachineScreen> {
  final _nomeCtrl = TextEditingController();
  final _ipCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  MachineType _type = MachineType.monitor;

  /// Enquanto `true`, o nome acompanha a sugestão automática do tipo; ao editar
  /// o campo manualmente, paramos de sobrescrever.
  bool _nameAutoFilled = true;

  @override
  void initState() {
    super.initState();
    _nomeCtrl.addListener(_onNameEdited);
  }

  @override
  void dispose() {
    _nomeCtrl.removeListener(_onNameEdited);
    _nomeCtrl.dispose();
    _ipCtrl.dispose();
    super.dispose();
  }

  void _onNameEdited() {
    // Edição feita pelo usuário (não pela sugestão) desliga o auto-preenchimento.
    if (_nomeCtrl.text != _suggestedName(_type)) _nameAutoFilled = false;
  }

  void _onTypeChanged(MachineType t) {
    setState(() {
      _type = t;
      if (_nameAutoFilled) {
        final nome = _suggestedName(t);
        _nomeCtrl.value = TextEditingValue(
          text: nome,
          selection: TextSelection.collapsed(offset: nome.length),
        );
      }
    });
  }

  /// Próximo nome sugerido para o tipo. Para TEX, escolhe `TEX N` com N = maior
  /// número já usado + 1 (cai para a contagem quando não há padrão numérico).
  String _suggestedName(MachineType type) {
    if (type != MachineType.tex) return '';
    final regex = RegExp(r'^TEX\s+(\d+)$', caseSensitive: false);
    var maxN = 0;
    var count = 0;
    for (final m in widget.existing) {
      if (m.type != MachineType.tex) continue;
      count++;
      final match = regex.firstMatch(m.nome.trim());
      if (match != null) {
        final n = int.tryParse(match.group(1)!) ?? 0;
        if (n > maxN) maxN = n;
      }
    }
    return 'TEX ${(maxN > count ? maxN : count) + 1}';
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    // `connection` fica no padrão (Modbus TCP) — o seletor de protocolo entra
    // no bloco avançado quando o multi-protocolo for de fato implementado.
    final machine = Machine(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      nome: _nomeCtrl.text.trim(),
      ip: _ipCtrl.text.trim(),
      type: _type,
    );
    Navigator.pop(context, machine);
  }

  /// Valida o IP e, além do formato, garante que não há outra máquina no mesmo
  /// endereço (cada bancada tem a sua própria instância/IP).
  String? _validateIp(String? value) {
    final base = IpValidator.validate(value);
    if (base != null) return base;
    final ip = value!.trim();
    if (widget.existing.any((m) => m.ip == ip)) {
      return 'Já existe uma máquina com este IP';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final tablet = AppTheme.isTablet(context);
    final maxW = tablet ? 560.0 : double.infinity;
    final hPad = tablet ? 48.0 : 24.0;

    return Scaffold(
      appBar: AppBar(title: const Text('NOVA MÁQUINA')),
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxW),
          child: Form(
            key: _formKey,
            child: ListView(
              padding: EdgeInsets.symmetric(horizontal: hPad, vertical: 28),
              children: [
                const _Label('Nome da máquina'),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _nomeCtrl,
                  style: const TextStyle(color: AppTheme.textPrimary),
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    hintText: 'Ex.: Torno CNC-01',
                    prefixIcon: Icon(Icons.precision_manufacturing_outlined,
                        color: AppTheme.textSecondary, size: 20),
                  ),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Informe o nome' : null,
                ),
                const SizedBox(height: 26),

                const _Label('Tipo de máquina'),
                const SizedBox(height: 10),
                _TypeSelector(
                  selected: _type,
                  onChanged: _onTypeChanged,
                ),
                const SizedBox(height: 26),

                const _Label('Endereço IP'),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _ipCtrl,
                  style: const TextStyle(
                      color: AppTheme.textPrimary, fontFamily: 'monospace'),
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    hintText: '192.168.1.10',
                    prefixIcon: Icon(Icons.router_outlined,
                        color: AppTheme.textSecondary, size: 20),
                  ),
                  validator: _validateIp,
                ),
                const SizedBox(height: 8),
                const Padding(
                  padding: EdgeInsets.only(left: 4),
                  child: Text(
                    'Onde o equipamento está na sua rede.',
                    style: TextStyle(
                        fontSize: 12, color: AppTheme.textSecondary),
                  ),
                ),
                const SizedBox(height: 40),

                ElevatedButton.icon(
                  onPressed: _save,
                  icon: const Icon(Icons.save_outlined),
                  label: const Text('Salvar máquina'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Seletor de tipo de máquina ───────────────────────────────────────────────

/// Lista de cartões — um por tipo. Cresce verticalmente conforme novos tipos
/// forem adicionados, sem redesenhar a tela.
class _TypeSelector extends StatelessWidget {
  const _TypeSelector({required this.selected, required this.onChanged});

  final MachineType selected;
  final ValueChanged<MachineType> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final type in MachineType.values) ...[
          _TypeOption(
            type: type,
            selected: type == selected,
            onTap: () => onChanged(type),
          ),
          if (type != MachineType.values.last) const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _TypeOption extends StatelessWidget {
  const _TypeOption({
    required this.type,
    required this.selected,
    required this.onTap,
  });

  final MachineType type;
  final bool selected;
  final VoidCallback onTap;

  IconData get _icon => type == MachineType.tex
      ? Icons.water_drop_outlined
      : Icons.monitor_heart_outlined;

  String get _description => type == MachineType.tex
      ? 'Pressão e vazamento (teste de estanqueidade).'
      : 'Produção, OEE e status do equipamento.';

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: selected
              ? AppTheme.accent.withValues(alpha: 0.10)
              : AppTheme.surfaceElevated,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? AppTheme.accent : AppTheme.border,
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(_icon,
                color: selected ? AppTheme.accent : AppTheme.textSecondary,
                size: 26),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    type.label,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: selected
                          ? AppTheme.textPrimary
                          : AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    _description,
                    style: const TextStyle(
                        fontSize: 12, color: AppTheme.textSecondary),
                  ),
                ],
              ),
            ),
            if (selected)
              const Icon(Icons.check_circle, color: AppTheme.accent, size: 22),
          ],
        ),
      ),
    );
  }
}

// ─── Auxiliares ───────────────────────────────────────────────────────────────

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 13,
        color: AppTheme.textSecondary,
        fontWeight: FontWeight.w500,
      ),
    );
  }
}