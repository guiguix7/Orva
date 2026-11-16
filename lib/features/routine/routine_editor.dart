import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/database/orva_repository.dart';
import '../../core/theme/orva_theme.dart';
import '../../core/widgets/orva_widgets.dart';

/// Routine block editor shared by the calendar, Home and any other entry point.
/// It always persists through OrvaRepository.saveRoutineBlock, so the calendar
/// never owns a second copy of the schedule.
Future<bool?> showRoutineEditor(
  BuildContext context,
  WidgetRef ref, {
  Map<String, Object?>? block,
  bool duplicate = false,
  DateTime? initialDate,
  int? initialStartMinute,
  String initialBlockKind = 'weekday',
}) async {
  final repo = ref.read(repositoryProvider);
  final title = TextEditingController(text: block?['title'] as String? ?? '');
  final category = TextEditingController(
    text: block?['category'] as String? ?? '',
  );
  final template = TextEditingController(
    text: block?['template_name'] as String? ?? '',
  );
  final startDefault = initialStartMinute ?? 9 * 60;
  String blockKind = block?['block_kind'] as String? ?? initialBlockKind;
  int weekday = intValue(
    block?['weekday'],
    (initialDate ?? DateTime.now()).weekday,
  );
  DateTime? selectedDate = block?['specific_date'] == null
      ? initialDate ?? DateTime.now()
      : DateTime.tryParse(block!['specific_date'] as String);
  TimeOfDay startTime = _minuteToTime(
    intValue(block?['start_minute'], startDefault),
  );
  TimeOfDay endTime = _minuteToTime(
    intValue(block?['end_minute'], startDefault + 60),
  );
  String? goalId = block?['goal_id'] as String?;
  String? hobbyId = block?['hobby_id'] as String?;
  final goals = await repo.getGoals(status: 'active');
  final hobbies = await repo.getHobbies();
  if (!context.mounted) return false;
  final formKey = GlobalKey<FormState>();
  final result = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: Text(
          block == null || duplicate ? 'Novo bloco de rotina' : 'Editar bloco',
        ),
        content: SizedBox(
          width: 450,
          child: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: title,
                    autofocus: true,
                    decoration: const InputDecoration(labelText: 'Atividade *'),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Informe uma atividade.'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: category,
                    decoration: const InputDecoration(
                      labelText: 'Categoria personalizada',
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: blockKind,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Tipo de bloco',
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'weekday',
                        child: Text('Recorrente por dia da semana'),
                      ),
                      DropdownMenuItem(
                        value: 'date',
                        child: Text('Data específica'),
                      ),
                    ],
                    onChanged: (value) =>
                        setState(() => blockKind = value ?? 'weekday'),
                  ),
                  const SizedBox(height: 12),
                  if (blockKind == 'weekday')
                    DropdownButtonFormField<int>(
                      initialValue: weekday,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Dia da semana',
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 1,
                          child: Text('Segunda-feira'),
                        ),
                        DropdownMenuItem(value: 2, child: Text('Terça-feira')),
                        DropdownMenuItem(value: 3, child: Text('Quarta-feira')),
                        DropdownMenuItem(value: 4, child: Text('Quinta-feira')),
                        DropdownMenuItem(value: 5, child: Text('Sexta-feira')),
                        DropdownMenuItem(value: 6, child: Text('Sábado')),
                        DropdownMenuItem(value: 7, child: Text('Domingo')),
                      ],
                      onChanged: (value) =>
                          setState(() => weekday = value ?? weekday),
                    )
                  else
                    OutlinedButton.icon(
                      onPressed: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: selectedDate ?? DateTime.now(),
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2100),
                        );
                        if (date != null) setState(() => selectedDate = date);
                      },
                      icon: const Icon(Icons.calendar_month_outlined),
                      label: Text(
                        selectedDate == null
                            ? 'Selecionar data'
                            : DateFormat('dd/MM/yyyy').format(selectedDate!),
                      ),
                    ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _TimeButton(
                          label: 'Início',
                          value: startTime,
                          onChanged: (value) =>
                              setState(() => startTime = value),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _TimeButton(
                          label: 'Fim',
                          value: endTime,
                          onChanged: (value) => setState(() => endTime = value),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Duração: ${formatMinutes((endTime.hour * 60 + endTime.minute) - (startTime.hour * 60 + startTime.minute))} (calculada pelos horários)',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String?>(
                    initialValue: goalId,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Meta vinculada (opcional)',
                    ),
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('Nenhuma'),
                      ),
                      ...goals.map(
                        (g) => DropdownMenuItem<String?>(
                          value: g['id'] as String,
                          child: Text(
                            '${g['title']}',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ],
                    onChanged: (value) => setState(() => goalId = value),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String?>(
                    initialValue: hobbyId,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Hobby vinculado (opcional)',
                    ),
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('Nenhum'),
                      ),
                      ...hobbies.map(
                        (h) => DropdownMenuItem<String?>(
                          value: h['id'] as String,
                          child: Text(
                            '${h['name']}',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ],
                    onChanged: (value) => setState(() => hobbyId = value),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: template,
                    decoration: const InputDecoration(
                      labelText: 'Nome do modelo semanal (opcional)',
                    ),
                  ),
                  const SizedBox(height: 4),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Blocos sobrepostos serão avisados, não bloqueados automaticamente.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              final start = startTime.hour * 60 + startTime.minute;
              final end = endTime.hour * 60 + endTime.minute;
              if (end <= start) {
                showOrvaError(
                  dialogContext,
                  'O horário final deve ser posterior ao inicial.',
                );
                return;
              }
              try {
                await repo.saveRoutineBlock(
                  id: block == null || duplicate ? null : block['id'] as String,
                  title: title.text,
                  category: category.text,
                  startMinute: start,
                  endMinute: end,
                  blockKind: blockKind,
                  weekday: blockKind == 'weekday' ? weekday : null,
                  specificDate: blockKind == 'date'
                      ? repo.dateKey(selectedDate ?? DateTime.now())
                      : null,
                  templateName: template.text,
                  goalId: goalId,
                  hobbyId: hobbyId,
                );
                if (dialogContext.mounted) Navigator.pop(dialogContext, true);
              } catch (error) {
                if (dialogContext.mounted) showOrvaError(dialogContext, error);
              }
            },
            child: const Text('Salvar bloco'),
          ),
        ],
      ),
    ),
  );
  title.dispose();
  category.dispose();
  template.dispose();
  return result;
}

Future<bool?> showRoutineTemplatesDialog(
  BuildContext context,
  WidgetRef ref,
) async {
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Salve uma cópia dos blocos recorrentes atuais para reutilizar depois. Blocos de data específica não fazem parte do modelo.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
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
                      if (dialogContext.mounted) {
                        showOrvaMessage(dialogContext, 'Modelo semanal salvo.');
                      }
                    } catch (error) {
                      if (dialogContext.mounted) {
                        showOrvaError(dialogContext, error);
                      }
                    }
                  },
                  icon: const Icon(Icons.save_outlined),
                  label: const Text('Salvar semana atual como modelo'),
                ),
              ),
              const Divider(height: 22),
              Expanded(
                child: templates.isEmpty
                    ? const OrvaEmptyState(
                        icon: Icons.view_week_outlined,
                        title: 'Nenhum modelo salvo',
                        message: 'Crie pelo menos um bloco recorrente e salve a semana como modelo.',
                        compact: true,
                      )
                    : ListView.separated(
                        itemCount: templates.length,
                        separatorBuilder: (_, _) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final template = templates[index];
                          final count = intValue(template['block_count']);
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text('${template['name']}'),
                            subtitle: Text(
                              '$count ${count == 1 ? 'bloco recorrente' : 'blocos recorrentes'}',
                            ),
                            trailing: Wrap(
                              children: [
                                IconButton(
                                  tooltip: 'Aplicar modelo e substituir blocos semanais',
                                  icon: const Icon(
                                    Icons.playlist_add_check_circle_outlined,
                                    color: OrvaColors.primary,
                                  ),
                                  onPressed: () async {
                                    final accepted = await confirmAction(
                                      context,
                                      title: 'Aplicar modelo semanal?',
                                      message:
                                          'Os blocos recorrentes atuais serão substituídos pelos blocos de “${template['name']}”. Blocos de datas específicas serão preservados.',
                                      actionLabel: 'Substituir semana',
                                    );
                                    if (!accepted || !dialogContext.mounted) {
                                      return;
                                    }
                                    try {
                                      await repo.applyRoutineTemplate(
                                        template['id'] as String,
                                      );
                                      if (dialogContext.mounted) {
                                        Navigator.pop(dialogContext, true);
                                      }
                                    } catch (error) {
                                      if (dialogContext.mounted) {
                                        showOrvaError(dialogContext, error);
                                      }
                                    }
                                  },
                                ),
                                IconButton(
                                  tooltip: 'Excluir modelo',
                                  icon: const Icon(
                                    Icons.delete_outline,
                                    color: OrvaColors.error,
                                  ),
                                  onPressed: () async {
                                    final accepted = await confirmAction(
                                      context,
                                      title: 'Excluir modelo?',
                                      message:
                                          'O modelo “${template['name']}” será removido. Blocos de rotina já aplicados não serão excluídos.',
                                      actionLabel: 'Excluir',
                                      destructive: true,
                                    );
                                    if (!accepted || !dialogContext.mounted) {
                                      return;
                                    }
                                    try {
                                      await repo.deleteRoutineTemplate(
                                        template['id'] as String,
                                      );
                                      templates = await repo
                                          .getRoutineTemplates();
                                      if (dialogContext.mounted) {
                                        setState(() {});
                                      }
                                    } catch (error) {
                                      if (dialogContext.mounted) {
                                        showOrvaError(dialogContext, error);
                                      }
                                    }
                                  },
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Fechar'),
          ),
        ],
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
          decoration: const InputDecoration(
            labelText: 'Nome do modelo *',
            hintText: 'Ex.: Semana de trabalho',
          ),
          validator: (value) =>
              value == null || value.trim().isEmpty ? 'Informe um nome.' : null,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () {
            if (formKey.currentState!.validate()) {
              Navigator.pop(dialogContext, controller.text.trim());
            }
          },
          child: const Text('Salvar'),
        ),
      ],
    ),
  );
  controller.dispose();
  return result;
}

TimeOfDay _minuteToTime(int minute) =>
    TimeOfDay(hour: (minute ~/ 60).clamp(0, 23), minute: minute % 60);

class _TimeButton extends StatelessWidget {
  const _TimeButton({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final TimeOfDay value;
  final ValueChanged<TimeOfDay> onChanged;

  @override
  Widget build(BuildContext context) => OutlinedButton(
    onPressed: () async {
      final picked = await showTimePicker(context: context, initialTime: value);
      if (picked != null) onChanged(picked);
    },
    style: OutlinedButton.styleFrom(
      padding: const EdgeInsets.symmetric(vertical: 14),
    ),
    child: Column(
      children: [
        Text(label, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 4),
        Text(
          value.format(context),
          style: Theme.of(context).textTheme.titleMedium
              ?.copyWith(fontFamily: 'monospace'),
        ),
      ],
    ),
  );
}
