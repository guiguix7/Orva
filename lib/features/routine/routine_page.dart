import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/database/orva_repository.dart';
import '../../core/theme/orva_theme.dart';
import '../../core/widgets/orva_widgets.dart';

class RoutinePage extends ConsumerStatefulWidget {
  const RoutinePage({super.key});
  @override
  ConsumerState<RoutinePage> createState() => _RoutinePageState();
}

class _RoutinePageState extends ConsumerState<RoutinePage> {
  DateTime _selectedDate = DateTime.now();
  bool _loading = true;
  List<Map<String, Object?>> _blocks = [];

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final blocks = await ref.read(repositoryProvider).getRoutineForDate(_selectedDate);
      if (!mounted) return;
      setState(() { _blocks = blocks; _loading = false; });
    } catch (error) { if (mounted) { setState(() => _loading = false); showOrvaError(context, error); } }
  }

  Future<void> _edit([Map<String, Object?>? block, bool duplicate = false]) async {
    await showRoutineEditor(context, ref, block: block, duplicate: duplicate, initialDate: _selectedDate);
    await _load();
  }

  List<String> _findOverlaps() {
    final overlaps = <String>[];
    for (var i = 0; i < _blocks.length; i++) {
      final a = _blocks[i];
      for (var j = i + 1; j < _blocks.length; j++) {
        final b = _blocks[j];
        final aStart = intValue(a['start_minute']);
        final aEnd = intValue(a['end_minute']);
        final bStart = intValue(b['start_minute']);
        final bEnd = intValue(b['end_minute']);
        if (aStart < bEnd && bStart < aEnd) {
          overlaps.add('${a['title']} (${formatClock(aStart)}–${formatClock(aEnd)}) e ${b['title']} (${formatClock(bStart)}–${formatClock(bEnd)})');
        }
      }
    }
    return overlaps;
  }

  @override
  Widget build(BuildContext context) {
    final totalMinutes = _blocks.fold<int>(0, (sum, b) => sum + intValue(b['end_minute']) - intValue(b['start_minute']));
    final overlaps = _findOverlaps();
    final categoryMinutes = <String, int>{};
    for (final block in _blocks) {
      final category = (block['category'] as String?)?.trim().isNotEmpty == true ? block['category'] as String : 'Sem categoria';
      categoryMinutes[category] = (categoryMinutes[category] ?? 0) + intValue(block['end_minute']) - intValue(block['start_minute']);
    }
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(onPressed: () => _edit(), icon: const Icon(Icons.add), label: const Text('Novo bloco')),
      body: SafeArea(child: Column(children: [
        OrvaPageHeader(
          title: 'Rotina',
          subtitle: 'Planejamento de tempo — não é registro de execução.',
          trailing: Row(mainAxisSize: MainAxisSize.min, children: [
            IconButton(tooltip: 'Modelos semanais', onPressed: () async { final applied = await showRoutineTemplatesDialog(context, ref); if (applied == true) await _load(); }, icon: const Icon(Icons.view_week_outlined)),
            IconButton(onPressed: () async { final d = await showDatePicker(context: context, initialDate: _selectedDate, firstDate: DateTime(2000), lastDate: DateTime(2100)); if (d != null) { setState(() => _selectedDate = d); await _load(); } }, icon: const Icon(Icons.calendar_month_outlined), tooltip: 'Escolher data'),
          ]),
        ),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: OrvaSurface(child: Row(children: [
          IconButton(tooltip: 'Dia anterior', onPressed: () async { setState(() => _selectedDate = _selectedDate.subtract(const Duration(days: 1))); await _load(); }, icon: const Icon(Icons.chevron_left)),
          Expanded(child: Column(children: [Text(_selectedDate.day == DateTime.now().day && _selectedDate.month == DateTime.now().month && _selectedDate.year == DateTime.now().year ? 'Hoje' : DateFormat('EEEE', 'pt_BR').format(_selectedDate), style: Theme.of(context).textTheme.titleMedium), const SizedBox(height: 2), Text(DateFormat('d MMMM yyyy', 'pt_BR').format(_selectedDate), style: Theme.of(context).textTheme.bodySmall)])),
          IconButton(tooltip: 'Próximo dia', onPressed: () async { setState(() => _selectedDate = _selectedDate.add(const Duration(days: 1))); await _load(); }, icon: const Icon(Icons.chevron_right)),
        ]))),
        const SizedBox(height: 12),
        Expanded(child: _loading ? const Center(child: CircularProgressIndicator()) : _blocks.isEmpty
            ? ListView(children: [OrvaEmptyState(icon: Icons.schedule_outlined, title: 'Nenhum bloco planejado', message: 'Adicione atividades com horários ou crie um bloco recorrente para um dia da semana.', actionLabel: 'Adicionar bloco', onAction: () => _edit())])
            : RefreshIndicator(onRefresh: _load, child: ListView(padding: const EdgeInsets.fromLTRB(20, 4, 20, 100), children: [
                OrvaSurface(child: Row(children: [
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(formatMinutes(totalMinutes), style: Theme.of(context).textTheme.titleLarge), const SizedBox(height: 2), Text('Tempo total planejado', style: Theme.of(context).textTheme.bodySmall)])),
                  Text('${_blocks.length} ${_blocks.length == 1 ? 'bloco' : 'blocos'}', style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                ])),
                if (overlaps.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  OrvaSurface(
                    color: Theme.of(context).brightness == Brightness.dark ? OrvaColors.darkSubtle : OrvaColors.accent100,
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Row(children: [Icon(Icons.warning_amber_rounded, color: OrvaColors.mustard), SizedBox(width: 8), Expanded(child: Text('Horários sobrepostos', style: TextStyle(fontWeight: FontWeight.w700)))]),
                      const SizedBox(height: 8),
                      const Text('Isso pode ser intencional. Revise os blocos que coincidem:'),
                      const SizedBox(height: 6),
                      for (final overlap in overlaps.take(3)) Padding(padding: const EdgeInsets.only(top: 5), child: Text('• $overlap')),
                      if (overlaps.length > 3) Padding(padding: const EdgeInsets.only(top: 5), child: Text('E mais ${overlaps.length - 3} sobreposições.')),
                    ]),
                  ),
                ],
                const SizedBox(height: 20),
                OrvaSectionHeader(title: 'Linha do tempo'),
                const SizedBox(height: 12),
                for (var index = 0; index < _blocks.length; index++) ...[
                  _RoutineBlockCard(block: _blocks[index], viewingDate: _selectedDate, onEdit: () => _edit(_blocks[index]), onDuplicate: () => _edit(_blocks[index], true), onDelete: () async {
                    final item = _blocks[index];
                    final ok = await confirmAction(context, title: 'Excluir bloco?', message: 'O bloco “${item['title']}” será removido do planejamento.', actionLabel: 'Excluir', destructive: true);
                    if (ok) { await ref.read(repositoryProvider).deleteRoutineBlock(item['id'] as String); await _load(); }
                  }),
                  const SizedBox(height: 10),
                ],
                const SizedBox(height: 20),
                OrvaSectionHeader(title: 'Distribuição por categoria'),
                const SizedBox(height: 6),
                Text('Percentual calculado sobre $totalMinutes minutos planejados neste dia.', style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 12),
                OrvaSurface(child: Column(children: [
                  for (final entry in (categoryMinutes.entries.toList()..sort((a, b) => b.value.compareTo(a.value))).indexed) ...[
                    Row(children: [Expanded(child: Text(entry.$2.key, style: Theme.of(context).textTheme.bodyLarge)), Text('${formatMinutes(entry.$2.value)} · ${totalMinutes == 0 ? '—' : (entry.$2.value / totalMinutes * 100).round()}%', style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600))]),
                    const SizedBox(height: 8),
                    ClipRRect(borderRadius: BorderRadius.circular(6), child: LinearProgressIndicator(value: totalMinutes == 0 ? 0 : entry.$2.value / totalMinutes, minHeight: 5, color: OrvaColors.information, backgroundColor: OrvaColors.primary100)),
                    if (entry.$1 < categoryMinutes.length - 1) const SizedBox(height: 16),
                  ],
                ])),
                const SizedBox(height: 18),
                const OrvaSurface(child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(Icons.info_outline_rounded, color: OrvaColors.information), SizedBox(width: 10), Expanded(child: Text('A rotina representa o que foi planejado. Para registrar tempo efetivamente realizado em hobbies, utilize o registro de sessões no módulo Hobbies.'))])),
              ]))),
      ])),
    );
  }
}

class _RoutineBlockCard extends StatelessWidget {
  const _RoutineBlockCard({required this.block, required this.viewingDate, required this.onEdit, required this.onDuplicate, required this.onDelete});
  final Map<String, Object?> block;
  final DateTime viewingDate;
  final VoidCallback onEdit;
  final VoidCallback onDuplicate;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final start = intValue(block['start_minute']);
    final end = intValue(block['end_minute']);
    final now = DateTime.now();
    final isToday = viewingDate.year == now.year && viewingDate.month == now.month && viewingDate.day == now.day;
    final isCurrent = isToday && now.hour * 60 + now.minute >= start && now.hour * 60 + now.minute < end;
    return OrvaSurface(padding: const EdgeInsets.all(0), child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Container(width: 4, decoration: BoxDecoration(color: isCurrent ? OrvaColors.terracotta : OrvaColors.information, borderRadius: const BorderRadius.horizontal(left: Radius.circular(16)))),
      Expanded(child: Padding(padding: const EdgeInsets.fromLTRB(14, 14, 6, 14), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(width: 62, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(formatClock(start), style: const TextStyle(fontFamily: 'monospace', fontSize: 14, fontWeight: FontWeight.w700)), const SizedBox(height: 4), Text(formatClock(end), style: Theme.of(context).textTheme.bodySmall?.copyWith(fontFamily: 'monospace')), const SizedBox(height: 7), Text(formatMinutes(end - start), style: Theme.of(context).textTheme.bodySmall)])),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${block['title']}', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text((block['category'] as String?)?.isNotEmpty == true ? '${block['category']}' : 'Sem categoria', style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 7),
          Wrap(spacing: 6, runSpacing: 6, children: [
            _SmallChip(label: block['block_kind'] == 'date' ? 'Data única · ${block['specific_date']}' : _weekdayLabel(intValue(block['weekday']))),
            if ((block['template_name'] as String?)?.isNotEmpty == true) _SmallChip(label: 'Modelo: ${block['template_name']}'),
            if (block['goal_title'] != null) _SmallChip(label: 'Meta: ${block['goal_title']}'),
            if (block['hobby_name'] != null) _SmallChip(label: 'Hobby: ${block['hobby_name']}'),
            if (isCurrent) const _SmallChip(label: 'Agora'),
          ]),
        ])),
        PopupMenuButton<String>(onSelected: (action) { if (action == 'edit') onEdit(); if (action == 'duplicate') onDuplicate(); if (action == 'delete') onDelete(); }, itemBuilder: (_) => const [PopupMenuItem(value: 'edit', child: Text('Editar')), PopupMenuItem(value: 'duplicate', child: Text('Duplicar')), PopupMenuItem(value: 'delete', child: Text('Excluir'))]),
      ]))),
    ]));
  }
}

class _SmallChip extends StatelessWidget {
  const _SmallChip({required this.label});
  final String label;
  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: Theme.of(context).brightness == Brightness.dark ? OrvaColors.darkSubtle : OrvaColors.subtle, borderRadius: BorderRadius.circular(7)), child: Text(label, style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 11)));
}

String _weekdayLabel(int weekday) => switch (weekday) {1=>'Toda segunda-feira',2=>'Toda terça-feira',3=>'Toda quarta-feira',4=>'Toda quinta-feira',5=>'Toda sexta-feira',6=>'Todo sábado',7=>'Todo domingo',_=>'Dia da semana'};

Future<bool?> showRoutineEditor(BuildContext context, WidgetRef ref, {Map<String, Object?>? block, bool duplicate = false, DateTime? initialDate}) async {
  final repo = ref.read(repositoryProvider);
  final title = TextEditingController(text: block?['title'] as String? ?? '');
  final category = TextEditingController(text: block?['category'] as String? ?? '');
  final template = TextEditingController(text: block?['template_name'] as String? ?? '');
  String blockKind = block?['block_kind'] as String? ?? 'weekday';
  int weekday = intValue(block?['weekday'], (initialDate ?? DateTime.now()).weekday);
  DateTime? selectedDate = block?['specific_date'] == null ? initialDate ?? DateTime.now() : DateTime.tryParse(block!['specific_date'] as String);
  TimeOfDay startTime = _minuteToTime(intValue(block?['start_minute'], 9 * 60));
  TimeOfDay endTime = _minuteToTime(intValue(block?['end_minute'], 10 * 60));
  String? goalId = block?['goal_id'] as String?;
  String? hobbyId = block?['hobby_id'] as String?;
  final goals = await repo.getGoals(status: 'active');
  final hobbies = await repo.getHobbies();
  if (!context.mounted) return false;
  final formKey = GlobalKey<FormState>();
  final result = await showDialog<bool>(context: context, builder: (dialogContext) => StatefulBuilder(builder: (context, setState) => AlertDialog(
    title: Text(block == null || duplicate ? 'Novo bloco de rotina' : 'Editar bloco'),
    content: SizedBox(width: 450, child: Form(key: formKey, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
      TextFormField(controller: title, autofocus: true, decoration: const InputDecoration(labelText: 'Atividade *'), validator: (value) => value == null || value.trim().isEmpty ? 'Informe uma atividade.' : null),
      const SizedBox(height: 12),
      TextFormField(controller: category, decoration: const InputDecoration(labelText: 'Categoria personalizada')),
      const SizedBox(height: 12),
      DropdownButtonFormField<String>(initialValue: blockKind, decoration: const InputDecoration(labelText: 'Tipo de bloco'), items: const [DropdownMenuItem(value: 'weekday', child: Text('Recorrente por dia da semana')), DropdownMenuItem(value: 'date', child: Text('Data específica'))], onChanged: (value) => setState(() => blockKind = value ?? 'weekday')),
      const SizedBox(height: 12),
      if (blockKind == 'weekday') DropdownButtonFormField<int>(initialValue: weekday, decoration: const InputDecoration(labelText: 'Dia da semana'), items: const [DropdownMenuItem(value: 1, child: Text('Segunda-feira')), DropdownMenuItem(value: 2, child: Text('Terça-feira')), DropdownMenuItem(value: 3, child: Text('Quarta-feira')), DropdownMenuItem(value: 4, child: Text('Quinta-feira')), DropdownMenuItem(value: 5, child: Text('Sexta-feira')), DropdownMenuItem(value: 6, child: Text('Sábado')), DropdownMenuItem(value: 7, child: Text('Domingo'))], onChanged: (value) => setState(() => weekday = value ?? weekday)) else OutlinedButton.icon(onPressed: () async { final date = await showDatePicker(context: context, initialDate: selectedDate ?? DateTime.now(), firstDate: DateTime(2000), lastDate: DateTime(2100)); if (date != null) setState(() => selectedDate = date); }, icon: const Icon(Icons.calendar_month_outlined), label: Text(selectedDate == null ? 'Selecionar data' : DateFormat('dd/MM/yyyy').format(selectedDate!))),
      const SizedBox(height: 12),
      Row(children: [Expanded(child: _TimeButton(label: 'Início', value: startTime, onChanged: (value) => setState(() => startTime = value))), const SizedBox(width: 8), Expanded(child: _TimeButton(label: 'Fim', value: endTime, onChanged: (value) => setState(() => endTime = value)))]),
      const SizedBox(height: 6),
      Align(alignment: Alignment.centerLeft, child: Text('Duração: ${formatMinutes((endTime.hour * 60 + endTime.minute) - (startTime.hour * 60 + startTime.minute))} (calculada pelos horários)', style: Theme.of(context).textTheme.bodySmall)),
      const SizedBox(height: 12),
      DropdownButtonFormField<String?>(initialValue: goalId, decoration: const InputDecoration(labelText: 'Meta vinculada (opcional)'), items: [const DropdownMenuItem<String?>(value: null, child: Text('Nenhuma')),...goals.map((g) => DropdownMenuItem<String?>(value: g['id'] as String, child: Text('${g['title']}', overflow: TextOverflow.ellipsis)))], onChanged: (value) => setState(() => goalId = value)),
      const SizedBox(height: 12),
      DropdownButtonFormField<String?>(initialValue: hobbyId, decoration: const InputDecoration(labelText: 'Hobby vinculado (opcional)'), items: [const DropdownMenuItem<String?>(value: null, child: Text('Nenhum')),...hobbies.map((h) => DropdownMenuItem<String?>(value: h['id'] as String, child: Text('${h['name']}', overflow: TextOverflow.ellipsis)))], onChanged: (value) => setState(() => hobbyId = value)),
      const SizedBox(height: 12),
      TextFormField(controller: template, decoration: const InputDecoration(labelText: 'Nome do modelo semanal (opcional)')),
      const SizedBox(height: 4),
      Align(alignment: Alignment.centerLeft, child: Text('Blocos sobrepostos serão avisados, não bloqueados automaticamente.', style: Theme.of(context).textTheme.bodySmall)),
    ])))),
    actions: [TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancelar')), FilledButton(onPressed: () async {
      if (!formKey.currentState!.validate()) return;
      final start = startTime.hour * 60 + startTime.minute;
      final end = endTime.hour * 60 + endTime.minute;
      if (end <= start) { showOrvaError(dialogContext, 'O horário final deve ser posterior ao inicial.'); return; }
      try {
        await repo.saveRoutineBlock(id: block == null || duplicate ? null : block['id'] as String, title: title.text, category: category.text, startMinute: start, endMinute: end, blockKind: blockKind, weekday: blockKind == 'weekday' ? weekday : null, specificDate: blockKind == 'date' ? repo.dateKey(selectedDate ?? DateTime.now()) : null, templateName: template.text, goalId: goalId, hobbyId: hobbyId);
        if (dialogContext.mounted) Navigator.pop(dialogContext, true);
      } catch (error) { if (dialogContext.mounted) showOrvaError(dialogContext, error); }
    }, child: const Text('Salvar bloco'))],
  )));
  title.dispose(); category.dispose(); template.dispose();
  return result;
}

Future<bool?> showRoutineTemplatesDialog(BuildContext context, WidgetRef ref) async {
  final repo = ref.read(repositoryProvider);
  var templates = await repo.getRoutineTemplates();
  if (!context.mounted) return false;
  return showDialog<bool>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: const Text('Modelos semanais'),
        content: SizedBox(
          width: 500,
          height: 430,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Salve uma cópia dos blocos recorrentes atuais para reutilizar depois. Blocos de data específica não fazem parte do modelo.', style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () async {
                  final name = await _askRoutineTemplateName(context);
                  if (name == null || !dialogContext.mounted) return;
                  try {
                    await repo.saveCurrentRoutineAsTemplate(name: name);
                    templates = await repo.getRoutineTemplates();
                    if (dialogContext.mounted) setState(() {});
                    if (dialogContext.mounted) showOrvaMessage(dialogContext, 'Modelo semanal salvo.');
                  } catch (error) {
                    if (dialogContext.mounted) showOrvaError(dialogContext, error);
                  }
                },
                icon: const Icon(Icons.save_outlined),
                label: const Text('Salvar semana atual como modelo'),
              ),
            ),
            const Divider(height: 22),
            Expanded(
              child: templates.isEmpty
                  ? const OrvaEmptyState(icon: Icons.view_week_outlined, title: 'Nenhum modelo salvo', message: 'Crie pelo menos um bloco recorrente e salve a semana como modelo.', compact: true)
                  : ListView.separated(
                      itemCount: templates.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final template = templates[index];
                        final count = intValue(template['block_count']);
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text('${template['name']}'),
                          subtitle: Text('$count ${count == 1 ? 'bloco recorrente' : 'blocos recorrentes'}'),
                          trailing: Wrap(children: [
                            IconButton(
                              tooltip: 'Aplicar modelo e substituir blocos semanais',
                              icon: const Icon(Icons.playlist_add_check_circle_outlined, color: OrvaColors.primary),
                              onPressed: () async {
                                final accepted = await confirmAction(context, title: 'Aplicar modelo semanal?', message: 'Os blocos recorrentes atuais serão substituídos pelos blocos de “${template['name']}”. Blocos de datas específicas serão preservados.', actionLabel: 'Substituir semana');
                                if (!accepted || !dialogContext.mounted) return;
                                try {
                                  await repo.applyRoutineTemplate(template['id'] as String);
                                  if (dialogContext.mounted) Navigator.pop(dialogContext, true);
                                } catch (error) {
                                  if (dialogContext.mounted) showOrvaError(dialogContext, error);
                                }
                              },
                            ),
                            IconButton(
                              tooltip: 'Excluir modelo',
                              icon: const Icon(Icons.delete_outline, color: OrvaColors.error),
                              onPressed: () async {
                                final accepted = await confirmAction(context, title: 'Excluir modelo?', message: 'O modelo “${template['name']}” será removido. Blocos de rotina já aplicados não serão excluídos.', actionLabel: 'Excluir', destructive: true);
                                if (!accepted || !dialogContext.mounted) return;
                                try {
                                  await repo.deleteRoutineTemplate(template['id'] as String);
                                  templates = await repo.getRoutineTemplates();
                                  if (dialogContext.mounted) setState(() {});
                                } catch (error) {
                                  if (dialogContext.mounted) showOrvaError(dialogContext, error);
                                }
                              },
                            ),
                          ]),
                        );
                      },
                    ),
            ),
          ]),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Fechar'))],
      ),
    ),
  );
}

Future<String?> _askRoutineTemplateName(BuildContext context) async {
  final controller = TextEditingController();
  final formKey = GlobalKey<FormState>();
  final result = await showDialog<String>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Salvar modelo semanal'),
      content: Form(
        key: formKey,
        child: TextFormField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Nome do modelo *', hintText: 'Ex.: Semana de trabalho'),
          validator: (value) => value == null || value.trim().isEmpty ? 'Informe um nome.' : null,
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancelar')),
        FilledButton(onPressed: () { if (formKey.currentState!.validate()) Navigator.pop(dialogContext, controller.text.trim()); }, child: const Text('Salvar')),
      ],
    ),
  );
  controller.dispose();
  return result;
}

TimeOfDay _minuteToTime(int minute) => TimeOfDay(hour: (minute ~/ 60).clamp(0, 23), minute: minute % 60);

class _TimeButton extends StatelessWidget {
  const _TimeButton({required this.label, required this.value, required this.onChanged});
  final String label;
  final TimeOfDay value;
  final ValueChanged<TimeOfDay> onChanged;
  @override
  Widget build(BuildContext context) => OutlinedButton(onPressed: () async { final picked = await showTimePicker(context: context, initialTime: value); if (picked != null) onChanged(picked); }, style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)), child: Column(children: [Text(label, style: Theme.of(context).textTheme.bodySmall), const SizedBox(height: 4), Text(value.format(context), style: Theme.of(context).textTheme.titleMedium?.copyWith(fontFamily: 'monospace'))]));
}
