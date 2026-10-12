import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/database/orva_repository.dart';
import '../../core/theme/orva_theme.dart';
import '../../core/widgets/orva_widgets.dart';

class ChecklistsPage extends ConsumerStatefulWidget {
  const ChecklistsPage({super.key});
  @override
  ConsumerState<ChecklistsPage> createState() => _ChecklistsPageState();
}

class _ChecklistsPageState extends ConsumerState<ChecklistsPage> {
  bool _loading = true;
  List<Map<String, Object?>> _checklists = [];
  List<Map<String, Object?>> _todayItems = [];
  String _filter = 'active';

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final repo = ref.read(repositoryProvider);
      final values = await Future.wait<Object?>([
        repo.getChecklists(includeArchived: _filter == 'archived', includeTemplates: true),
        repo.getTodayOccurrenceItems(),
      ]);
      if (!mounted) return;
      setState(() { _checklists = values[0] as List<Map<String, Object?>>; _todayItems = values[1] as List<Map<String, Object?>>; _loading = false; });
    } catch (error) {
      if (!mounted) return;
      setState(() => _loading = false);
      showOrvaError(context, error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final displayed = _checklists.where((item) {
      final isArchived = intValue(item['is_active']) == 0;
      final isTemplate = intValue(item['is_template']) == 1;
      if (_filter == 'archived') return isArchived;
      return !isArchived && (_filter == 'templates' ? isTemplate : !isTemplate);
    }).toList();
    final total = _todayItems.length;
    final done = _todayItems.where((item) => intValue(item['completed']) == 1).length;
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(onPressed: () async { await showChecklistEditor(context, ref); await _load(); }, icon: const Icon(Icons.add), label: const Text('Novo checklist')),
      body: SafeArea(child: Column(children: [
        OrvaPageHeader(title: 'Checklists', subtitle: DateFormat('EEEE, d MMMM', 'pt_BR').format(DateTime.now())),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: OrvaSurface(padding: const EdgeInsets.all(16), child: Row(children: [
          Container(width: 42, height: 42, decoration: BoxDecoration(color: OrvaColors.mustard.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(13)), child: const Icon(Icons.checklist_rounded, color: Color(0xFF9B701A))),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Progresso de hoje', style: Theme.of(context).textTheme.titleMedium), const SizedBox(height: 3), Text(total == 0 ? 'Sem itens elegíveis para esta data.' : '$done de $total itens concluídos', style: Theme.of(context).textTheme.bodySmall)])),
          Text(total == 0 ? '—' : '${(done / total * 100).round()}%', style: Theme.of(context).textTheme.titleLarge?.copyWith(color: OrvaColors.primary)),
        ]))),
        const SizedBox(height: 14),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: SegmentedButton<String>(
          segments: const [ButtonSegment(value: 'active', label: Text('Checklists')), ButtonSegment(value: 'templates', label: Text('Templates')), ButtonSegment(value: 'archived', label: Text('Arquivados'))],
          selected: {_filter}, showSelectedIcon: false,
          onSelectionChanged: (selected) { setState(() => _filter = selected.first); _load(); },
        )),
        const SizedBox(height: 8),
        Expanded(child: _loading
            ? const Center(child: CircularProgressIndicator())
            : displayed.isEmpty
                ? ListView(children: [OrvaEmptyState(icon: Icons.checklist_outlined, title: _filter == 'templates' ? 'Nenhum template criado' : _filter == 'archived' ? 'Nenhum checklist arquivado' : 'Comece com um checklist seu', message: _filter == 'templates' ? 'Salve um checklist como template para reutilizá-lo quando fizer sentido.' : _filter == 'archived' ? 'Checklists arquivados aparecerão aqui. O histórico deles é preservado.' : 'Checklists diários, semanais ou de uma data específica ficam organizados aqui.', actionLabel: _filter == 'archived' ? null : _filter == 'templates' ? 'Criar template' : 'Criar checklist', onAction: _filter == 'archived' ? null : () async { await showChecklistEditor(context, ref, asTemplate: _filter == 'templates'); await _load(); })])
                : RefreshIndicator(onRefresh: _load, child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 6, 20, 100),
                    itemCount: displayed.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final checklist = displayed[index];
                      final id = checklist['id'] as String;
                      final items = _todayItems.where((item) => item['checklist_id'] == id).toList();
                      final doneCount = items.where((item) => intValue(item['completed']) == 1).length;
                      return _ChecklistCard(
                        checklist: checklist, todayItems: items, completedCount: doneCount,
                        onOpen: () async { await showChecklistDetails(context, ref, checklist); await _load(); },
                        onEdit: () async { await showChecklistEditor(context, ref, checklist: checklist); await _load(); },
                        onArchive: () async {
                          final accepted = await confirmAction(context, title: 'Arquivar checklist?', message: 'O checklist deixará de gerar novas ocorrências. As ocorrências anteriores serão mantidas.', actionLabel: 'Arquivar');
                          if (accepted && mounted) { await ref.read(repositoryProvider).archiveChecklist(id); await _load(); }
                        },
                        onRestore: () async { await ref.read(repositoryProvider).restoreChecklist(id); await _load(); },
                        onDelete: () async {
                          final accepted = await confirmAction(context, title: 'Excluir checklist e histórico?', message: 'A definição, seus itens e todas as ocorrências salvas serão removidos permanentemente. Esta ação não pode ser desfeita.', actionLabel: 'Excluir permanentemente', destructive: true);
                          if (accepted && mounted) { await ref.read(repositoryProvider).deleteChecklist(id); await _load(); }
                        },
                        onUseTemplate: () async { await _useTemplate(checklist); },
                        onToggleItem: (item, checked) async { await ref.read(repositoryProvider).setOccurrenceItemCompleted(item['id'] as String, checked); await _load(); },
                      );
                    },
                  ))),
      ])),
    );
  }

  Future<void> _useTemplate(Map<String, Object?> template) async {
    final repo = ref.read(repositoryProvider);
    try {
      final items = await repo.getChecklistItems(template['id'] as String);
      final date = repo.dateKey(DateTime.now());
      final before = (await repo.getChecklists(includeTemplates: false)).map((item) => item['id']).toSet();
      await repo.saveChecklist(title: '${template['title']}', description: '${template['description'] ?? ''}', recurrence: 'once', scheduledDate: date);
      final definitions = await repo.getChecklists(includeTemplates: false);
      final made = definitions.firstWhere((item) => !before.contains(item['id']) && item['scheduled_date'] == date);
      for (final item in items) {
        await repo.addChecklistItem(checklistId: made['id'] as String, title: item['title'] as String, goalId: item['goal_id'] as String?);
      }
      await _load();
      if (mounted) showOrvaMessage(context, 'Template aplicado ao checklist de hoje.');
    } catch (error) { if (mounted) showOrvaError(context, error); }
  }
}

class _ChecklistCard extends StatelessWidget {
  const _ChecklistCard({required this.checklist, required this.todayItems, required this.completedCount, required this.onOpen, required this.onEdit, required this.onArchive, required this.onRestore, required this.onDelete, required this.onUseTemplate, required this.onToggleItem});
  final Map<String, Object?> checklist;
  final List<Map<String, Object?>> todayItems;
  final int completedCount;
  final VoidCallback onOpen;
  final VoidCallback onEdit;
  final VoidCallback onArchive;
  final VoidCallback onRestore;
  final VoidCallback onDelete;
  final VoidCallback onUseTemplate;
  final void Function(Map<String, Object?> item, bool checked) onToggleItem;

  @override
  Widget build(BuildContext context) {
    final isTemplate = intValue(checklist['is_template']) == 1;
    final isArchived = intValue(checklist['is_active']) == 0;
    final hasToday = todayItems.isNotEmpty;
    final recurrence = _recurrenceLabel(checklist);
    final progress = todayItems.isEmpty ? null : completedCount / todayItems.length;
    return OrvaSurface(padding: const EdgeInsets.all(0), child: Column(children: [
      Padding(padding: const EdgeInsets.fromLTRB(16, 14, 8, 12), child: Row(children: [
        Container(width: 42, height: 42, decoration: BoxDecoration(color: OrvaColors.mustard.withValues(alpha: 0.17), borderRadius: BorderRadius.circular(12)), child: Icon(isTemplate ? Icons.copy_all_outlined : Icons.checklist_rounded, color: const Color(0xFF9B701A))),
        const SizedBox(width: 12),
        Expanded(child: InkWell(onTap: onOpen, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${checklist['title']}', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 3),
          Text(recurrence, style: Theme.of(context).textTheme.bodySmall),
        ]))),
        PopupMenuButton<String>(onSelected: (value) { if (value == 'edit') onEdit(); if (value == 'archive') onArchive(); if (value == 'use') onUseTemplate(); if (value == 'restore') onRestore(); if (value == 'delete') onDelete(); }, itemBuilder: (_) => [
          if (isTemplate && !isArchived) const PopupMenuItem(value: 'use', child: Text('Usar template')),
          const PopupMenuItem(value: 'edit', child: Text('Editar')),
          if (!isArchived) const PopupMenuItem(value: 'archive', child: Text('Arquivar')),
          if (isArchived) const PopupMenuItem(value: 'restore', child: Text('Restaurar')),
          if (isArchived) const PopupMenuItem(value: 'delete', child: Text('Excluir definição e histórico')),
        ]),
      ])),
      if (!isArchived && !isTemplate && hasToday) ...[
        Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Row(children: [Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(5), child: LinearProgressIndicator(value: progress, minHeight: 5, color: OrvaColors.primary, backgroundColor: OrvaColors.primary100))), const SizedBox(width: 10), Text('$completedCount/${todayItems.length}', style: Theme.of(context).textTheme.bodySmall)])),
        const SizedBox(height: 7),
        for (var i = 0; i < todayItems.length; i++) CheckboxListTile(
          value: intValue(todayItems[i]['completed']) == 1,
          onChanged: (value) => onToggleItem(todayItems[i], value ?? false),
          dense: true, controlAffinity: ListTileControlAffinity.leading,
          contentPadding: const EdgeInsets.symmetric(horizontal: 10),
          title: Text('${todayItems[i]['title_snapshot']}', style: Theme.of(context).textTheme.bodyMedium?.copyWith(decoration: intValue(todayItems[i]['completed']) == 1 ? TextDecoration.lineThrough : null)),
          subtitle: todayItems.length == 1 ? null : null,
          activeColor: OrvaColors.primary,
        ),
      ] else ...[
        Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 14), child: Row(children: [
          Expanded(child: Text(isArchived ? 'Arquivado. O histórico foi preservado.' : isTemplate ? 'Modelo reutilizável; não gera tarefas por conta própria.' : 'Sem itens para hoje. Abra para adicionar itens ou consultar o checklist.', style: Theme.of(context).textTheme.bodySmall)),
          TextButton(onPressed: onOpen, child: const Text('Abrir')),
        ])),
      ],
    ]));
  }
}

String _recurrenceLabel(Map<String, Object?> checklist) {
  if (intValue(checklist['is_template']) == 1) return 'Template reutilizável';
  switch (checklist['recurrence']) {
    case 'daily': return 'Todos os dias';
    case 'weekly':
      final raw = jsonDecode((checklist['weekdays_json'] as String?) ?? '[]') as List<dynamic>;
      const labels = {1:'Seg',2:'Ter',3:'Qua',4:'Qui',5:'Sex',6:'Sáb',7:'Dom'};
      return 'Semanal · ${raw.map((day) => labels[(day as num).toInt()] ?? '?').join(', ')}';
    default: return 'Data única · ${checklist['scheduled_date'] ?? 'sem data'}';
  }
}

Future<void> showAddTodayTaskDialog(BuildContext context, WidgetRef ref) async {
  final controller = TextEditingController();
  final formKey = GlobalKey<FormState>();
  await showDialog<void>(context: context, builder: (dialogContext) => AlertDialog(
    title: const Text('Adicionar tarefa de hoje'),
    content: Form(key: formKey, child: TextFormField(controller: controller, autofocus: true, decoration: const InputDecoration(labelText: 'O que você precisa fazer?', hintText: 'Descreva uma ação concreta'), validator: (value) => value == null || value.trim().isEmpty ? 'Escreva a tarefa.' : null)),
    actions: [TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancelar')), FilledButton(onPressed: () async {
      if (!formKey.currentState!.validate()) return;
      try {
        final repo = ref.read(repositoryProvider);
        final date = repo.dateKey(DateTime.now());
        final title = 'Tarefas avulsas · $date';
        var list = await repo.getChecklists(includeTemplates: false);
        final matches = list.where((item) => item['title'] == title && item['scheduled_date'] == date).toList();
        Map<String, Object?>? checklist = matches.isEmpty ? null : matches.first;
        if (checklist == null) {
          await repo.saveChecklist(title: title, recurrence: 'once', scheduledDate: date);
          list = await repo.getChecklists(includeTemplates: false);
          checklist = list.firstWhere((item) => item['title'] == title && item['scheduled_date'] == date);
        }
        await repo.addChecklistItem(checklistId: checklist['id'] as String, title: controller.text);
        if (dialogContext.mounted) Navigator.pop(dialogContext);
        if (context.mounted) showOrvaMessage(context, 'Tarefa adicionada ao checklist de hoje.');
      } catch (error) { if (dialogContext.mounted) showOrvaError(dialogContext, error); }
    }, child: const Text('Adicionar'))],
  ));
  controller.dispose();
}

Future<bool?> showChecklistEditor(BuildContext context, WidgetRef ref, {Map<String, Object?>? checklist, bool asTemplate = false}) async {
  final repo = ref.read(repositoryProvider);
  final title = TextEditingController(text: checklist?['title'] as String? ?? '');
  final description = TextEditingController(text: checklist?['description'] as String? ?? '');
  final isTemplateControllerValue = asTemplate || intValue(checklist?['is_template']) == 1;
  String recurrence = checklist?['recurrence'] as String? ?? 'daily';
  DateTime? scheduled = checklist?['scheduled_date'] == null ? DateTime.now() : DateTime.tryParse(checklist!['scheduled_date'] as String);
  DateTime? start = checklist == null ? DateTime.now() : checklist['start_date'] == null ? null : DateTime.tryParse(checklist['start_date'] as String);
  DateTime? end = checklist?['end_date'] == null ? null : DateTime.tryParse(checklist!['end_date'] as String);
  final rawWeekdays = checklist?['weekdays_json'] as String? ?? '[1,2,3,4,5,6,7]';
  final weekdays = (jsonDecode(rawWeekdays) as List<dynamic>).map((e) => (e as num).toInt()).toSet();
  final formKey = GlobalKey<FormState>();
  if (isTemplateControllerValue) recurrence = 'template';
  final result = await showDialog<bool>(context: context, builder: (dialogContext) => StatefulBuilder(builder: (context, setState) => AlertDialog(
    title: Text(checklist == null ? (isTemplateControllerValue ? 'Novo template' : 'Novo checklist') : 'Editar checklist'),
    content: SizedBox(width: 450, child: Form(key: formKey, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
      TextFormField(controller: title, autofocus: true, decoration: const InputDecoration(labelText: 'Nome *'), validator: (value) => value == null || value.trim().isEmpty ? 'Informe um nome.' : null),
      const SizedBox(height: 12),
      TextFormField(controller: description, decoration: const InputDecoration(labelText: 'Descrição (opcional)'), maxLines: 3),
      const SizedBox(height: 12),
      DropdownButtonFormField<String>(initialValue: recurrence, decoration: const InputDecoration(labelText: 'Frequência'), items: const [
        DropdownMenuItem(value: 'once', child: Text('Uma data específica')),
        DropdownMenuItem(value: 'daily', child: Text('Todos os dias')),
        DropdownMenuItem(value: 'weekly', child: Text('Dias da semana')),
        DropdownMenuItem(value: 'template', child: Text('Template reutilizável')),
      ], onChanged: (value) => setState(() => recurrence = value ?? 'daily')),
      if (recurrence == 'once') ...[
        const SizedBox(height: 12),
        _DateButton(label: 'Data do checklist', date: scheduled, onChanged: (date) => setState(() => scheduled = date)),
      ],
      if (recurrence == 'daily' || recurrence == 'weekly') ...[
        const SizedBox(height: 12),
        Row(children: [Expanded(child: _DateButton(label: 'Começa em', date: start, onChanged: (date) => setState(() => start = date))), const SizedBox(width: 8), Expanded(child: _DateButton(label: 'Termina em (opcional)', date: end, onChanged: (date) => setState(() => end = date))) ]),
      ],
      if (recurrence == 'weekly') ...[
        const SizedBox(height: 12),
        Align(alignment: Alignment.centerLeft, child: Text('Repetir em', style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600))),
        const SizedBox(height: 6),
        Wrap(spacing: 5, children: [for (final entry in const {1:'Seg',2:'Ter',3:'Qua',4:'Qui',5:'Sex',6:'Sáb',7:'Dom'}.entries) FilterChip(label: Text(entry.value), selected: weekdays.contains(entry.key), onSelected: (selected) => setState(() { selected ? weekdays.add(entry.key) : weekdays.remove(entry.key); }))]),
      ],
      const SizedBox(height: 10),
      Align(alignment: Alignment.centerLeft, child: Text('As conclusões ficam salvas por data. Editar a definição não altera snapshots anteriores.', style: Theme.of(context).textTheme.bodySmall)),
    ])))),
    actions: [TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancelar')), FilledButton(onPressed: () async {
      if (!formKey.currentState!.validate()) return;
      try {
        await repo.saveChecklist(id: checklist?['id'] as String?, title: title.text, description: description.text, recurrence: recurrence, weekdays: weekdays.toList(), scheduledDate: recurrence == 'once' ? repo.dateKey(scheduled ?? DateTime.now()) : null, startDate: (recurrence == 'daily' || recurrence == 'weekly') && start != null ? repo.dateKey(start!) : null, endDate: (recurrence == 'daily' || recurrence == 'weekly') && end != null ? repo.dateKey(end!) : null, isTemplate: recurrence == 'template');
        if (dialogContext.mounted) Navigator.pop(dialogContext, true);
      } catch (error) { if (dialogContext.mounted) showOrvaError(dialogContext, error); }
    }, child: const Text('Salvar'))],
  )));
  title.dispose(); description.dispose();
  return result;
}

Future<void> showChecklistDetails(BuildContext context, WidgetRef ref, Map<String, Object?> checklist) async {
  final repo = ref.read(repositoryProvider);
  final id = checklist['id'] as String;
  List<Map<String, Object?>> items = await repo.getChecklistItems(id);
  List<Map<String, Object?>> history = await repo.getOccurrenceHistory(id);
  if (!context.mounted) return;
  var showingHistory = false;
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheetContext) => StatefulBuilder(
      builder: (context, setSheetState) => SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(20, 4, 20, MediaQuery.of(context).viewInsets.bottom + 24),
          child: SizedBox(
            height: MediaQuery.of(context).size.height * 0.72,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${checklist['title']}', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 4),
              Text(_recurrenceLabel(checklist), style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 14),
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: false, label: Text('Itens')),
                  ButtonSegment(value: true, label: Text('Histórico')),
                ],
                selected: {showingHistory},
                showSelectedIcon: false,
                onSelectionChanged: (selected) async {
                  if (selected.first) history = await repo.getOccurrenceHistory(id);
                  if (!selected.first) items = await repo.getChecklistItems(id);
                  if (!sheetContext.mounted) return;
                  setSheetState(() => showingHistory = selected.first);
                },
              ),
              const SizedBox(height: 12),
              if (showingHistory)
                Expanded(
                  child: history.isEmpty
                      ? const OrvaEmptyState(icon: Icons.history_rounded, title: 'Sem histórico ainda', message: 'As ocorrências serão registradas quando este checklist for elegível para uma data.', compact: true)
                      : ListView.separated(
                          itemCount: history.length,
                          separatorBuilder: (_, _) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final occurrence = history[index];
                            final total = intValue(occurrence['total']);
                            final completed = intValue(occurrence['completed']);
                            final date = DateTime.parse(occurrence['reference_date'] as String);
                            return ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: const Icon(Icons.event_available_outlined, color: OrvaColors.primary),
                              title: Text(DateFormat('EEEE, d MMMM yyyy', 'pt_BR').format(date)),
                              subtitle: Text(total == 0 ? 'Ocorrência sem itens' : '$completed de $total itens concluídos'),
                              trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                                Text(total == 0 ? '—' : '${(completed / total * 100).round()}%', style: Theme.of(context).textTheme.titleSmall),
                                const SizedBox(width: 6),
                                const Icon(Icons.chevron_right_rounded, color: OrvaColors.tertiaryText),
                              ]),
                              onTap: () async {
                                final snapshots = await repo.getOccurrenceSnapshotItems(id, occurrence['reference_date'] as String);
                                if (!sheetContext.mounted) return;
                                await showModalBottomSheet<void>(
                                  context: sheetContext,
                                  showDragHandle: true,
                                  builder: (historyContext) => SafeArea(
                                    child: SizedBox(
                                      height: MediaQuery.of(historyContext).size.height * 0.55,
                                      child: Padding(
                                        padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                          Text(DateFormat('d MMMM yyyy', 'pt_BR').format(date), style: Theme.of(historyContext).textTheme.titleLarge),
                                          const SizedBox(height: 4),
                                          Text('Snapshot preservado dessa ocorrência.', style: Theme.of(historyContext).textTheme.bodySmall),
                                          const SizedBox(height: 12),
                                          Expanded(
                                            child: snapshots.isEmpty
                                                ? const OrvaEmptyState(icon: Icons.checklist_outlined, title: 'Sem itens registrados', message: 'Esta ocorrência não possui snapshots de itens.', compact: true)
                                                : ListView.separated(
                                                    itemCount: snapshots.length,
                                                    separatorBuilder: (_, _) => const Divider(height: 1),
                                                    itemBuilder: (historyContext, itemIndex) {
                                                      final snapshot = snapshots[itemIndex];
                                                      final checked = intValue(snapshot['completed']) == 1;
                                                      return ListTile(
                                                        contentPadding: EdgeInsets.zero,
                                                        leading: Icon(checked ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded, color: checked ? OrvaColors.success : OrvaColors.tertiaryText),
                                                        title: Text('${snapshot['title_snapshot']}', style: Theme.of(historyContext).textTheme.bodyLarge?.copyWith(decoration: checked ? TextDecoration.lineThrough : null)),
                                                        subtitle: checked && snapshot['completed_at'] != null ? Text('Concluído em ${DateFormat('HH:mm').format(DateTime.parse(snapshot['completed_at'] as String))}') : null,
                                                      );
                                                    },
                                                  ),
                                          ),
                                        ]),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            );
                          },
                        ),
                )
              else ...[
                Row(children: [
                  Expanded(child: Text('Itens', style: Theme.of(context).textTheme.titleMedium)),
                  TextButton.icon(
                    onPressed: () async {
                      final itemController = TextEditingController();
                      final formKey = GlobalKey<FormState>();
                      await showDialog<void>(
                        context: context,
                        builder: (dialogContext) => AlertDialog(
                          title: const Text('Novo item'),
                          content: Form(
                            key: formKey,
                            child: TextFormField(
                              controller: itemController,
                              autofocus: true,
                              decoration: const InputDecoration(labelText: 'Descrição'),
                              validator: (value) => value == null || value.trim().isEmpty ? 'Informe o item.' : null,
                            ),
                          ),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancelar')),
                            FilledButton(
                              onPressed: () async {
                                if (!formKey.currentState!.validate()) return;
                                try {
                                  await repo.addChecklistItem(checklistId: id, title: itemController.text);
                                  if (dialogContext.mounted) Navigator.pop(dialogContext);
                                } catch (error) {
                                  if (dialogContext.mounted) showOrvaError(dialogContext, error);
                                }
                              },
                              child: const Text('Adicionar'),
                            ),
                          ],
                        ),
                      );
                      itemController.dispose();
                      items = await repo.getChecklistItems(id);
                      if (sheetContext.mounted) setSheetState(() {});
                    },
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Adicionar'),
                  ),
                ]),
                const SizedBox(height: 8),
                if (items.isEmpty)
                  const Expanded(child: OrvaEmptyState(icon: Icons.add_task, title: 'Checklist sem itens', message: 'Adicione as ações que farão parte desta lista.', compact: true))
                else
                  Expanded(
                    child: ReorderableListView.builder(
                      itemCount: items.length,
                      onReorder: (oldIndex, newIndex) async {
                        if (newIndex > oldIndex) newIndex--;
                        final item = items.removeAt(oldIndex);
                        items.insert(newIndex, item);
                        await repo.reorderChecklistItems(items.map((e) => e['id'] as String).toList());
                        if (sheetContext.mounted) setSheetState(() {});
                      },
                      itemBuilder: (context, index) {
                        final item = items[index];
                        return ListTile(
                          key: ValueKey(item['id']),
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.drag_handle_rounded, color: OrvaColors.tertiaryText),
                          title: Text('${item['title']}'),
                          trailing: PopupMenuButton<String>(
                            onSelected: (action) async {
                              if (action == 'edit') {
                                final controller = TextEditingController(text: item['title'] as String);
                                final formKey = GlobalKey<FormState>();
                                await showDialog<void>(
                                  context: context,
                                  builder: (dialogContext) => AlertDialog(
                                    title: const Text('Editar item'),
                                    content: Form(
                                      key: formKey,
                                      child: TextFormField(
                                        controller: controller,
                                        autofocus: true,
                                        decoration: const InputDecoration(labelText: 'Descrição'),
                                        validator: (value) => value == null || value.trim().isEmpty ? 'Informe o item.' : null,
                                      ),
                                    ),
                                    actions: [
                                      TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancelar')),
                                      FilledButton(
                                        onPressed: () async {
                                          if (!formKey.currentState!.validate()) return;
                                          try {
                                            await repo.updateChecklistItem(item['id'] as String, controller.text);
                                            if (dialogContext.mounted) Navigator.pop(dialogContext);
                                          } catch (error) {
                                            if (dialogContext.mounted) showOrvaError(dialogContext, error);
                                          }
                                        },
                                        child: const Text('Salvar'),
                                      ),
                                    ],
                                  ),
                                );
                                controller.dispose();
                                items = await repo.getChecklistItems(id);
                                if (sheetContext.mounted) setSheetState(() {});
                              } else if (action == 'remove') {
                                final accepted = await confirmAction(
                                  context,
                                  title: 'Remover item?',
                                  message: 'O item não aparecerá em novas ocorrências. O histórico anterior será preservado.',
                                  actionLabel: 'Remover',
                                  destructive: true,
                                );
                                if (accepted) {
                                  await repo.archiveChecklistItem(item['id'] as String);
                                  items = await repo.getChecklistItems(id);
                                  if (sheetContext.mounted) setSheetState(() {});
                                }
                              }
                            },
                            itemBuilder: (_) => const [
                              PopupMenuItem(value: 'edit', child: Text('Editar')),
                              PopupMenuItem(value: 'remove', child: Text('Remover')),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
              ],
              const SizedBox(height: 8),
              SizedBox(width: double.infinity, child: FilledButton(onPressed: () => Navigator.pop(sheetContext), child: const Text('Concluir'))),
            ]),
          ),
        ),
      ),
    ),
  );
}

class _DateButton extends StatelessWidget {
  const _DateButton({required this.label, required this.date, required this.onChanged});
  final String label;
  final DateTime? date;
  final ValueChanged<DateTime?> onChanged;
  @override
  Widget build(BuildContext context) => OutlinedButton(
    onPressed: () async {
      final value = await showDatePicker(context: context, initialDate: date ?? DateTime.now(), firstDate: DateTime(2000), lastDate: DateTime(2100));
      if (value != null) onChanged(value);
    },
    style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12), alignment: Alignment.centerLeft),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: Theme.of(context).textTheme.bodySmall), const SizedBox(height: 3), Text(date == null ? 'Selecionar' : DateFormat('dd/MM/yyyy').format(date!), style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurface))]),
  );
}
