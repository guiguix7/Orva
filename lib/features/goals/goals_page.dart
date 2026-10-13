import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/database/orva_repository.dart';
import '../../core/domain/orva_calculations.dart';
import '../../core/theme/orva_theme.dart';
import '../../core/widgets/orva_widgets.dart';

class GoalsPage extends ConsumerStatefulWidget {
  const GoalsPage({super.key});
  @override
  ConsumerState<GoalsPage> createState() => _GoalsPageState();
}

class _GoalsPageState extends ConsumerState<GoalsPage> {
  bool _loading = true;
  String _filter = 'active';
  List<Map<String, Object?>> _goals = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final goals = await ref.read(repositoryProvider).getGoals(status: _filter);
      if (!mounted) return;
      setState(() { _goals = goals; _loading = false; });
    } catch (error) {
      if (!mounted) return;
      setState(() => _loading = false);
      showOrvaError(context, error);
    }
  }

  Future<void> _archive(Map<String, Object?> goal) async {
    final confirmed = await confirmAction(context, title: 'Arquivar meta?', message: '“${goal['title']}” sairá da lista ativa. O histórico e os vínculos serão preservados.', actionLabel: 'Arquivar');
    if (!confirmed || !mounted) return;
    try {
      await ref.read(repositoryProvider).setGoalStatus(goal['id'] as String, 'archived');
      await _load();
    } catch (error) { if (mounted) showOrvaError(context, error); }
  }

  Future<void> _delete(Map<String, Object?> goal) async {
    final confirmed = await confirmAction(context, title: 'Excluir meta permanentemente?', message: '“${goal['title']}” e o histórico de progresso dela serão removidos. Metas filhas e itens vinculados deixarão de apontar para esta meta. Esta ação não pode ser desfeita.', actionLabel: 'Excluir', destructive: true);
    if (!confirmed || !mounted) return;
    try {
      await ref.read(repositoryProvider).deleteGoal(goal['id'] as String);
      await _load();
    } catch (error) { if (mounted) showOrvaError(context, error); }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'goals-create',
        onPressed: () async { await showGoalEditor(context, ref); await _load(); },
        icon: const Icon(Icons.add), label: const Text('Nova meta'),
      ),
      body: SafeArea(child: Column(children: [
        const OrvaPageHeader(title: 'Metas', subtitle: 'Objetivos claros, progresso baseado nos seus registros.'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'active', label: Text('Ativas')),
              ButtonSegment(value: 'completed', label: Text('Concluídas')),
              ButtonSegment(value: 'archived', label: Text('Arquivadas')),
            ],
            selected: {_filter},
            showSelectedIcon: false,
            onSelectionChanged: (values) { setState(() => _filter = values.first); _load(); },
          ),
        ),
        const SizedBox(height: 14),
        Expanded(child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _goals.isEmpty
                ? ListView(children: [OrvaEmptyState(icon: Icons.flag_outlined, title: _filter == 'active' ? 'Nenhuma meta ativa' : 'Nada por aqui ainda', message: _filter == 'active' ? 'Cadastre um objetivo seu. Você pode começar só pelo título e completar os detalhes depois.' : 'As metas que chegarem a este estado aparecerão aqui.', actionLabel: _filter == 'active' ? 'Criar minha primeira meta' : null, onAction: _filter == 'active' ? () async { await showGoalEditor(context, ref); await _load(); } : null)])
                : RefreshIndicator(onRefresh: _load, child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 100),
                    itemCount: _goals.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, index) => _GoalCard(
                      goal: _goals[index],
                      onTap: () => _showGoalHistory(_goals[index]),
                      onEdit: () async { await showGoalEditor(context, ref, goal: _goals[index]); await _load(); },
                      onComplete: () async {
                        final current = _goals[index];
                        final next = (current['status'] as String) == 'completed' ? 'active' : 'completed';
                        await ref.read(repositoryProvider).setGoalStatus(current['id'] as String, next);
                        await _load();
                      },
                      onArchive: () => _archive(_goals[index]),
                      onRestore: () async { await ref.read(repositoryProvider).setGoalStatus(_goals[index]['id'] as String, 'active'); await _load(); },
                      onDelete: () => _delete(_goals[index]),
                    ),
                  ))),
      ])),
    );
  }

  Future<void> _showGoalHistory(Map<String, Object?> goal) async {
    final history = await ref.read(repositoryProvider).getGoalHistory(goal['id'] as String);
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => SafeArea(child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${goal['title']}', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 5),
          Text('Histórico de progresso manual', style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 16),
          if (history.isEmpty) const Text('Nenhum registro de progresso.'),
          for (final row in history.take(12))
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.trending_up, color: OrvaColors.primary),
              title: Text('${doubleValue(row['progress_value']).round()}%'),
              subtitle: Text('${row['note']}'),
              trailing: Text(DateFormat('dd/MM/yy · HH:mm').format(DateTime.parse(row['recorded_at'] as String)), style: Theme.of(context).textTheme.bodySmall),
            ),
          const SizedBox(height: 12),
          SizedBox(width: double.infinity, child: FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Fechar'))),
        ]),
      )),
    );
  }
}

class _GoalCard extends StatelessWidget {
  const _GoalCard({required this.goal, required this.onTap, required this.onEdit, required this.onComplete, required this.onArchive, required this.onRestore, required this.onDelete});
  final Map<String, Object?> goal;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onComplete;
  final VoidCallback onArchive;
  final VoidCallback onRestore;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final progress = (doubleValue(goal['progress_value']) / 100).clamp(0.0, 1.0);
    final status = goal['status'] as String;
    return OrvaSurface(onTap: onTap, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(width: 40, height: 40, decoration: BoxDecoration(color: OrvaColors.primary.withValues(alpha: 0.09), borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.flag_outlined, color: OrvaColors.primary)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${goal['title']}', style: Theme.of(context).textTheme.titleMedium),
          if ((goal['category'] as String?)?.isNotEmpty == true) ...[const SizedBox(height: 3), Text('${goal['category']}', style: Theme.of(context).textTheme.bodySmall)],
        ])),
        PopupMenuButton<String>(
          tooltip: 'Ações da meta',
          onSelected: (choice) { if (choice == 'edit') onEdit(); if (choice == 'complete') onComplete(); if (choice == 'archive') onArchive(); if (choice == 'restore') onRestore(); if (choice == 'delete') onDelete(); },
          itemBuilder: (_) => [
            const PopupMenuItem(value: 'edit', child: Text('Editar')),
            PopupMenuItem(value: 'complete', child: Text(status == 'completed' ? 'Reabrir meta' : 'Marcar como concluída')),
            if (status == 'archived') const PopupMenuItem(value: 'restore', child: Text('Restaurar meta ativa')),
            if (status != 'archived') const PopupMenuItem(value: 'archive', child: Text('Arquivar')),
            const PopupMenuItem(value: 'delete', child: Text('Excluir permanentemente')),
          ],
        ),
      ]),
      if ((goal['description'] as String?)?.isNotEmpty == true) ...[const SizedBox(height: 12), Text('${goal['description']}', style: Theme.of(context).textTheme.bodyMedium)],
      const SizedBox(height: 16),
      Row(children: [
        Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(6), child: LinearProgressIndicator(value: progress, minHeight: 6, backgroundColor: OrvaColors.primary100, color: OrvaColors.primary))),
        const SizedBox(width: 12),
        Text('${(progress * 100).round()}%', style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700, color: OrvaColors.primary)),
      ]),
      const SizedBox(height: 12),
      Wrap(spacing: 8, runSpacing: 8, children: [
        _MetaChip(label: _periodLabel(goal['period'] as String)),
        if (goal['deadline'] != null) _MetaChip(label: 'Prazo ${goal['deadline']}'),
        _MetaChip(label: status == 'active' ? 'Em andamento' : status == 'completed' ? 'Concluída' : 'Arquivada'),
        if (goal['target_value'] != null) _MetaChip(label: 'Alvo ${goal['target_value']}${goal['unit'] == null ? '' : ' ${goal['unit']}'}'),
      ]),
    ]));
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.label});
  final String label;
  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), decoration: BoxDecoration(color: Theme.of(context).brightness == Brightness.dark ? OrvaColors.darkSubtle : OrvaColors.subtle, borderRadius: BorderRadius.circular(8)), child: Text(label, style: Theme.of(context).textTheme.bodySmall));
}

String _periodLabel(String period) => switch (period) {
  'daily' => 'Diária', 'weekly' => 'Semanal', 'monthly' => 'Mensal', 'quarterly' => 'Trimestral', 'yearly' => 'Anual', _ => 'Sem período',
};

Future<bool?> showGoalEditor(BuildContext context, WidgetRef ref, {Map<String, Object?>? goal}) async {
  final repo = ref.read(repositoryProvider);
  final goals = await repo.getGoals();
  if (!context.mounted) return false;
  final title = TextEditingController(text: goal?['title'] as String? ?? '');
  final description = TextEditingController(text: goal?['description'] as String? ?? '');
  final category = TextEditingController(text: goal?['category'] as String? ?? '');
  final metric = TextEditingController(text: goal?['metric_name'] as String? ?? '');
  final target = TextEditingController(text: goal?['target_value']?.toString() ?? '');
  final unit = TextEditingController(text: goal?['unit'] as String? ?? '');
  final progress = TextEditingController(text: (goal?['progress_value'] as num?)?.toString() ?? '0');
  String period = goal?['period'] as String? ?? 'open';
  String? parentId = goal?['parent_id'] as String?;
  DateTime? startDate = _parseDate(goal?['start_date'] as String?) ?? (goal == null ? DateTime.now() : null);
  DateTime? deadline = _parseDate(goal?['deadline'] as String?);
  if (goal == null && startDate != null) deadline = suggestedGoalDeadline(period, startDate);
  bool deadlineEdited = goal != null;
  final formKey = GlobalKey<FormState>();
  final result = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(builder: (context, setState) => AlertDialog(
      title: Text(goal == null ? 'Nova meta' : 'Editar meta'),
      content: SizedBox(
        width: 460,
        child: Form(key: formKey, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextFormField(controller: title, autofocus: true, decoration: const InputDecoration(labelText: 'Título *', hintText: 'Qual objetivo você quer alcançar?'), validator: (value) => value == null || value.trim().isEmpty ? 'Informe um título.' : null),
          const SizedBox(height: 12),
          TextFormField(controller: description, decoration: const InputDecoration(labelText: 'Descrição (opcional)'), minLines: 2, maxLines: 4),
          const SizedBox(height: 12),
          TextFormField(controller: category, decoration: const InputDecoration(labelText: 'Categoria personalizada (opcional)')),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(initialValue: period, decoration: const InputDecoration(labelText: 'Período'), items: const [
            DropdownMenuItem(value: 'open', child: Text('Sem período definido')),
            DropdownMenuItem(value: 'daily', child: Text('Diário')),
            DropdownMenuItem(value: 'weekly', child: Text('Semanal')),
            DropdownMenuItem(value: 'monthly', child: Text('Mensal')),
            DropdownMenuItem(value: 'quarterly', child: Text('Trimestral')),
            DropdownMenuItem(value: 'yearly', child: Text('Anual')),
          ], onChanged: (value) => setState(() { period = value ?? 'open'; if (!deadlineEdited && startDate != null) deadline = suggestedGoalDeadline(period, startDate!); })),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: _DateSelect(label: 'Início', value: startDate, onChanged: (date) => setState(() { startDate = date; if (!deadlineEdited) deadline = date == null ? null : suggestedGoalDeadline(period, date); }))),
            const SizedBox(width: 8),
            Expanded(child: _DateSelect(label: 'Prazo sugerido (editável)', value: deadline, onChanged: (date) => setState(() { deadline = date; deadlineEdited = true; }))),
          ]),
          const SizedBox(height: 4),
          Align(alignment: Alignment.centerLeft, child: Text('Início preenchido na criação; o prazo acompanha o período, mas pode ser alterado.', style: Theme.of(context).textTheme.bodySmall)),
          const SizedBox(height: 12),
          DropdownButtonFormField<String?>(
            initialValue: parentId,
            decoration: const InputDecoration(labelText: 'Meta superior (opcional)'),
            items: [const DropdownMenuItem<String?>(value: null, child: Text('Sem vínculo')),...goals.where((item) => item['id'] != goal?['id']).map((item) => DropdownMenuItem<String?>(value: item['id'] as String, child: Text('${item['title']}', overflow: TextOverflow.ellipsis)))],
            onChanged: (value) => setState(() => parentId = value),
          ),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: TextFormField(controller: metric, decoration: const InputDecoration(labelText: 'Indicador (opcional)'))),
            const SizedBox(width: 8),
            Expanded(child: TextFormField(controller: target, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Valor-alvo'), validator: (value) { if (value == null || value.trim().isEmpty) return null; final parsed = double.tryParse(value.replaceAll(',', '.')); return parsed == null || !parsed.isFinite ? 'Informe um número finito.' : null; })),
            const SizedBox(width: 8),
            SizedBox(width: 84, child: TextFormField(controller: unit, decoration: const InputDecoration(labelText: 'Unidade'))),
          ]),
          const SizedBox(height: 12),
          TextFormField(controller: progress, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Progresso manual (%)'), validator: (value) { final number = double.tryParse((value ?? '').replaceAll(',', '.')); return number == null || !number.isFinite || number < 0 || number > 100 ? 'Use um valor de 0 a 100.' : null; }),
          const SizedBox(height: 5),
          Align(alignment: Alignment.centerLeft, child: Text('O progresso não é estimado pelo texto da meta.', style: Theme.of(context).textTheme.bodySmall)),
        ]))),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancelar')),
        FilledButton(onPressed: () async {
          if (!formKey.currentState!.validate()) return;
          try {
            await repo.saveGoal(
              id: goal?['id'] as String?, title: title.text, description: description.text,
              period: period, category: category.text, startDate: startDate == null ? null : repo.dateKey(startDate!),
              deadline: deadline == null ? null : repo.dateKey(deadline!), metricName: metric.text,
              targetValue: target.text.trim().isEmpty ? null : double.parse(target.text.replaceAll(',', '.')),
              unit: unit.text, progress: double.parse(progress.text.replaceAll(',', '.')), parentId: parentId,
              status: goal?['status'] as String? ?? 'active',
            );
            if (dialogContext.mounted) Navigator.pop(dialogContext, true);
          } catch (error) { if (dialogContext.mounted) showOrvaError(dialogContext, error); }
        }, child: const Text('Salvar meta')),
      ],
    )),
  );
  title.dispose(); description.dispose(); category.dispose(); metric.dispose(); target.dispose(); unit.dispose(); progress.dispose();
  return result;
}

DateTime? _parseDate(String? value) => value == null ? null : DateTime.tryParse(value);

class _DateSelect extends StatelessWidget {
  const _DateSelect({required this.label, required this.value, required this.onChanged});
  final String label;
  final DateTime? value;
  final ValueChanged<DateTime?> onChanged;
  @override
  Widget build(BuildContext context) => Row(children: [
        Expanded(
          child: OutlinedButton(
            onPressed: () async {
              final date = await showDatePicker(context: context, initialDate: value ?? DateTime.now(), firstDate: DateTime(2000), lastDate: DateTime(2100), helpText: label);
              if (date != null) onChanged(date);
            },
            style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14), alignment: Alignment.centerLeft),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label, style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 4),
              Text(value == null ? 'Selecionar' : DateFormat('dd/MM/yyyy').format(value!), style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurface)),
            ]),
          ),
        ),
        if (value != null) IconButton(tooltip: 'Remover data', visualDensity: VisualDensity.compact, icon: const Icon(Icons.close, size: 18), onPressed: () => onChanged(null)),
      ]);
}
