import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/database/orva_repository.dart';
import '../../core/database/study_repository.dart';
import '../../core/theme/orva_theme.dart';
import '../../core/widgets/orva_widgets.dart';

class StudyPage extends ConsumerStatefulWidget {
  const StudyPage({super.key});
  @override
  ConsumerState<StudyPage> createState() => _StudyPageState();
}

class _StudyPageState extends ConsumerState<StudyPage> {
  bool _loading = true;
  bool _archived = false;
  List<Map<String, Object?>> _subjects = [];
  List<Map<String, Object?>> _sessions = [];
  List<Map<String, Object?>> _reviews = [];
  Map<String, Object?> _summary = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final repo = ref.read(repositoryProvider);
      final now = DateTime.now();
      final monday = DateTime(now.year, now.month, now.day - now.weekday + 1);
      final values = await Future.wait<Object?>([
        repo.getStudySubjects(includeArchived: true),
        repo.getStudySessions(limit: 30),
        repo.getStudyReviews(limit: 10),
        repo.getStudySummary(from: monday, to: now),
      ]);
      if (!mounted) return;
      final all = values[0] as List<Map<String, Object?>>;
      setState(() {
        _subjects = all.where((s) => intValue(s['is_active']) == (_archived ? 0 : 1)).toList();
        _sessions = values[1] as List<Map<String, Object?>>;
        _reviews = values[2] as List<Map<String, Object?>>;
        _summary = values[3] as Map<String, Object?>;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _loading = false);
      showOrvaError(context, error);
    }
  }

  Future<void> _editSubject([Map<String, Object?>? subject]) async {
    final name = TextEditingController(text: subject?['name'] as String? ?? '');
    final description = TextEditingController(text: subject?['description'] as String? ?? '');
    final goals = await ref.read(repositoryProvider).getGoals(status: 'active');
    var goalId = subject?['goal_id'] as String? ?? '';
    if (!mounted) { name.dispose(); description.dispose(); return; }
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialog) => StatefulBuilder(builder: (context, setDialog) => AlertDialog(
        title: Text(subject == null ? 'Nova matéria' : 'Editar matéria'),
        content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: name, autofocus: true, maxLength: 100, decoration: const InputDecoration(labelText: 'Nome *')),
          const SizedBox(height: 8),
          TextField(controller: description, maxLines: 3, decoration: const InputDecoration(labelText: 'Descrição')),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: goalId,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Meta relacionada (opcional)'),
            items: [
              const DropdownMenuItem(value: '', child: Text('Sem meta')),
              ...goals.map((g) => DropdownMenuItem(value: g['id'] as String, child: Text('${g['title']}', overflow: TextOverflow.ellipsis))),
            ],
            onChanged: (v) => setDialog(() => goalId = v ?? ''),
          ),
        ])),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialog, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () {
            if (name.text.trim().isEmpty) { showOrvaMessage(dialog, 'Informe o nome da matéria.'); return; }
            Navigator.pop(dialog, true);
          }, child: const Text('Salvar')),
        ],
      )),
    );
    if (ok == true && mounted) {
      try {
        await ref.read(repositoryProvider).saveStudySubject(
          id: subject?['id'] as String?,
          name: name.text,
          description: description.text,
          goalId: goalId.isEmpty ? null : goalId,
        );
        await _load();
      } catch (error) { if (mounted) showOrvaError(context, error); }
    }
    name.dispose();
    description.dispose();
  }

  Future<void> _editTopic(Map<String, Object?> subject, {Map<String, Object?>? topic, Map<String, Object?>? parent}) async {
    final repo = ref.read(repositoryProvider);
    final allTopics = await repo.getStudyTopics(subject['id'] as String);
    final name = TextEditingController(text: topic?['name'] as String? ?? '');
    final description = TextEditingController(text: topic?['description'] as String? ?? '');
    var parentId = (parent?['id'] ?? topic?['parent_topic_id'] ?? '') as String;
    var status = topic?['status'] as String? ?? 'not_started';
    if (!mounted) { name.dispose(); description.dispose(); return; }
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialog) => StatefulBuilder(builder: (context, setDialog) => AlertDialog(
        title: Text(topic != null ? 'Editar assunto' : parent != null ? 'Novo subtópico' : 'Novo assunto'),
        content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: name, autofocus: true, maxLength: 120, decoration: const InputDecoration(labelText: 'Nome *')),
          const SizedBox(height: 8),
          TextField(controller: description, maxLines: 2, decoration: const InputDecoration(labelText: 'Descrição/observações')),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: parentId,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Assunto pai'),
            items: [
              const DropdownMenuItem(value: '', child: Text('Nenhum')),
              ...allTopics.where((t) => t['id'] != topic?['id']).map((t) => DropdownMenuItem(
                value: t['id'] as String,
                child: Text('${t['parent_name'] == null ? '' : '${t['parent_name']} › '}${t['name']}', overflow: TextOverflow.ellipsis),
              )),
            ],
            onChanged: (v) => setDialog(() => parentId = v ?? ''),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: status,
            decoration: const InputDecoration(labelText: 'Estado'),
            items: const [
              DropdownMenuItem(value: 'not_started', child: Text('Não iniciado')),
              DropdownMenuItem(value: 'in_progress', child: Text('Em andamento')),
              DropdownMenuItem(value: 'completed', child: Text('Concluído')),
            ],
            onChanged: (v) => setDialog(() => status = v ?? 'not_started'),
          ),
        ])),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialog, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () {
            if (name.text.trim().isEmpty) { showOrvaMessage(dialog, 'Informe o nome do assunto.'); return; }
            Navigator.pop(dialog, true);
          }, child: const Text('Salvar')),
        ],
      )),
    );
    if (ok == true && mounted) {
      try {
        await repo.saveStudyTopic(
          id: topic?['id'] as String?,
          subjectId: subject['id'] as String,
          parentTopicId: parentId.isEmpty ? null : parentId,
          name: name.text,
          description: description.text,
          status: status,
          orderIndex: intValue(topic?['order_index']),
        );
        await _load();
      } catch (error) { if (mounted) showOrvaError(context, error); }
    }
    name.dispose();
    description.dispose();
  }

  Future<void> _logSession({
    String? selectedSubject,
    Map<String, Object?>? session,
  }) async {
    final subjects = _subjects.where((s) => intValue(s['is_active']) == 1).toList();
    if (subjects.isEmpty) { showOrvaMessage(context, 'Crie uma matéria ativa antes de registrar um estudo.'); return; }
    final desiredSubject = session?['subject_id'] as String? ?? selectedSubject;
    var subjectId = subjects.any((s) => s['id'] == desiredSubject)
        ? desiredSubject!
        : subjects.first['id'] as String;
    var topics = await ref.read(repositoryProvider).getStudyTopics(subjectId);
    var topicId = session?['topic_id'] as String? ?? '';
    if (!topics.any((topic) => topic['id'] == topicId)) topicId = '';
    final goals = await ref.read(repositoryProvider).getGoals(status: 'active');
    var goalId = session?['goal_id'] as String? ?? '';
    if (!goals.any((goal) => goal['id'] == goalId)) goalId = '';
    var date = DateTime.tryParse(session?['session_date'] as String? ?? '') ?? DateTime.now();
    var minute = (session?['start_minute'] as num?)?.toInt() ??
        date.hour * 60 + date.minute;
    final duration = TextEditingController(
      text: session == null ? '30' : '${session['duration_minutes']}',
    );
    final note = TextEditingController(text: session?['note'] as String? ?? '');
    if (!mounted) { duration.dispose(); note.dispose(); return; }
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialog) => StatefulBuilder(builder: (context, setDialog) => AlertDialog(
        title: Text(session == null ? 'Registrar sessão de estudo' : 'Editar sessão de estudo'),
        content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
          DropdownButtonFormField<String>(
            initialValue: subjectId,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Matéria *'),
            items: subjects.map((s) => DropdownMenuItem(value: s['id'] as String, child: Text('${s['name']}', overflow: TextOverflow.ellipsis))).toList(),
            onChanged: (v) async {
              subjectId = v ?? subjectId;
              topics = await ref.read(repositoryProvider).getStudyTopics(subjectId);
              setDialog(() => topicId = '');
            },
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: topicId,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Assunto (opcional)'),
            items: [
              const DropdownMenuItem(value: '', child: Text('Sem assunto')),
              ...topics.map((t) => DropdownMenuItem(value: t['id'] as String, child: Text('${t['name']}', overflow: TextOverflow.ellipsis))),
            ],
            onChanged: (v) => setDialog(() => topicId = v ?? ''),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: goalId,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Meta (opcional)'),
            items: [
              const DropdownMenuItem(value: '', child: Text('Sem meta')),
              ...goals.map((g) => DropdownMenuItem(value: g['id'] as String, child: Text('${g['title']}', overflow: TextOverflow.ellipsis))),
            ],
            onChanged: (v) => setDialog(() => goalId = v ?? ''),
          ),
          OutlinedButton.icon(
            onPressed: () async {
              final picked = await showDatePicker(context: context, initialDate: date, firstDate: DateTime(2000), lastDate: DateTime(2100));
              if (picked != null) setDialog(() => date = picked);
            },
            icon: const Icon(Icons.calendar_today_outlined),
            label: Text('Data: ${DateFormat('dd/MM/yyyy','pt_BR').format(date)}'),
          ),
          OutlinedButton.icon(
            onPressed: () async {
              final picked = await showTimePicker(context: context, initialTime: TimeOfDay(hour: minute ~/ 60, minute: minute % 60));
              if (picked != null) setDialog(() => minute = picked.hour * 60 + picked.minute);
            },
            icon: const Icon(Icons.schedule_outlined),
            label: Text('Início: ${formatClock(minute)}'),
          ),
          TextField(controller: duration, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Duração (minutos) *')),
          const SizedBox(height: 8),
          TextField(controller: note, maxLines: 2, decoration: const InputDecoration(labelText: 'Observações')),
        ])),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialog, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () {
            final parsed = int.tryParse(duration.text);
            if (parsed == null || parsed < 1 || parsed > 1440) { showOrvaMessage(dialog, 'Informe uma duração entre 1 e 1440 minutos.'); return; }
            Navigator.pop(dialog, true);
          }, child: Text(session == null ? 'Salvar sessão' : 'Salvar alterações')),
        ],
      )),
    );
    if (ok == true && mounted) {
      try {
        await ref.read(repositoryProvider).saveStudySession(
          id: session?['id'] as String?,
          subjectId: subjectId,
          topicId: topicId.isEmpty ? null : topicId,
          goalId: goalId.isEmpty ? null : goalId,
          sessionDate: date,
          startMinute: minute,
          durationMinutes: int.parse(duration.text),
          note: note.text,
        );
        await _load();
      } catch (error) { if (mounted) showOrvaError(context, error); }
    }
    duration.dispose();
    note.dispose();
  }

  Future<void> _planStudyBlock(
    Map<String, Object?> subject, {
    Map<String, Object?>? topic,
  }) async {
    final repo = ref.read(repositoryProvider);
    final duration = TextEditingController(text: '45');
    var date = DateTime.now();
    var startMinute = ((date.hour * 60 + date.minute + 4) ~/ 5) * 5;
    if (startMinute + 45 > 1440) startMinute = 22 * 60;
    if (!mounted) {
      duration.dispose();
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialog) => StatefulBuilder(
        builder: (context, setDialog) => AlertDialog(
          title: const Text('Planejar sessão de estudo'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(
                topic == null
                    ? 'Matéria: ${subject['name']}'
                    : 'Matéria: ${subject['name']}\nAssunto: ${topic['name']}',
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: date,
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                  );
                  if (picked != null) setDialog(() => date = picked);
                },
                icon: const Icon(Icons.calendar_today_outlined),
                label: Text(DateFormat('dd/MM/yyyy', 'pt_BR').format(date)),
              ),
              OutlinedButton.icon(
                onPressed: () async {
                  final picked = await showTimePicker(
                    context: context,
                    initialTime: TimeOfDay(
                      hour: startMinute ~/ 60,
                      minute: startMinute % 60,
                    ),
                  );
                  if (picked != null) {
                    setDialog(() => startMinute = picked.hour * 60 + picked.minute);
                  }
                },
                icon: const Icon(Icons.schedule_outlined),
                label: Text('Início: ${formatClock(startMinute)}'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: duration,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Duração em minutos *',
                  helperText: 'O bloco vai para a rotina. Ele não registra estudo realizado.',
                ),
              ),
            ]),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialog, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () {
                final minutes = int.tryParse(duration.text.trim());
                if (minutes == null || minutes < 1 || minutes > 1440) {
                  showOrvaMessage(dialog, 'Informe uma duração inteira entre 1 e 1440 minutos.');
                  return;
                }
                if (startMinute + minutes > 1440) {
                  showOrvaMessage(dialog, 'A sessão planejada deve terminar antes da meia-noite. Escolha outro horário ou duração.');
                  return;
                }
                Navigator.pop(dialog, true);
              },
              child: const Text('Adicionar à rotina'),
            ),
          ],
        ),
      ),
    );

    if (ok == true && mounted) {
      try {
        final minutes = int.parse(duration.text.trim());
        final title = topic == null
            ? 'Estudar · ${subject['name']}'
            : 'Estudar · ${subject['name']} · ${topic['name']}';
        await repo.saveRoutineBlock(
          title: title,
          category: 'Estudos',
          startMinute: startMinute,
          endMinute: startMinute + minutes,
          blockKind: 'date',
          specificDate: repo.dateKey(date),
          goalId: subject['goal_id'] as String?,
        );
        if (mounted) {
          showOrvaMessage(
            context,
            'Sessão adicionada à rotina. Para contar como realizada, registre a sessão depois do estudo.',
          );
        }
      } catch (error) {
        if (mounted) showOrvaError(context, error);
      }
    }
    duration.dispose();
  }

  Future<void> _review(Map<String, Object?> subject, Map<String, Object?> topic) async {
    final note = TextEditingController();
    var confidence = 3;
    var kind = 'review';
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialog) => StatefulBuilder(builder: (context, setDialog) => AlertDialog(
        title: Text('Revisar: ${topic['name']}'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          DropdownButtonFormField<String>(
            initialValue: kind,
            decoration: const InputDecoration(labelText: 'Tipo de revisão'),
            items: const [
              DropdownMenuItem(value: 'review', child: Text('Revisão')),
              DropdownMenuItem(value: 'quiz', child: Text('Exercícios/teste')),
              DropdownMenuItem(value: 'summary', child: Text('Resumo')),
            ],
            onChanged: (v) => setDialog(() => kind = v ?? 'review'),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<int>(
            initialValue: confidence,
            decoration: const InputDecoration(labelText: 'Confiança (1 a 5)'),
            items: const [
              DropdownMenuItem(value: 1, child: Text('1 · Preciso revisar bastante')),
              DropdownMenuItem(value: 2, child: Text('2 · Ainda inseguro')),
              DropdownMenuItem(value: 3, child: Text('3 · Parcial')),
              DropdownMenuItem(value: 4, child: Text('4 · Seguro')),
              DropdownMenuItem(value: 5, child: Text('5 · Consigo explicar')),
            ],
            onChanged: (v) => setDialog(() => confidence = v ?? 3),
          ),
          const SizedBox(height: 8),
          TextField(controller: note, maxLines: 3, decoration: const InputDecoration(labelText: 'Notas para a próxima revisão')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialog, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(dialog, true), child: const Text('Registrar revisão')),
        ],
      )),
    );
    if (ok == true && mounted) {
      try {
        await ref.read(repositoryProvider).saveStudyReview(
          subjectId: subject['id'] as String,
          topicId: topic['id'] as String,
          reviewedAt: DateTime.now(),
          reviewKind: kind,
          confidence: confidence,
          note: note.text,
        );
        await _load();
      } catch (error) { if (mounted) showOrvaError(context, error); }
    }
    note.dispose();
  }

  Future<void> _deleteTopic(Map<String, Object?> topic) async {
    final ok = await confirmAction(context, title: 'Excluir assunto?', message: 'Só é possível excluir assuntos sem subtópicos, sessões ou revisões, para preservar o histórico.', actionLabel: 'Excluir', destructive: true);
    if (!ok || !mounted) return;
    try {
      await ref.read(repositoryProvider).deleteStudyTopic(topic['id'] as String);
      await _load();
    } catch (error) { if (mounted) showOrvaError(context, error); }
  }

  Future<void> _toggleArchive(Map<String, Object?> subject) async {
    final active = intValue(subject['is_active']) == 1;
    final ok = await confirmAction(context, title: active ? 'Arquivar matéria?' : 'Restaurar matéria?', message: 'Assuntos, sessões e revisões serão preservados.', actionLabel: active ? 'Arquivar' : 'Restaurar');
    if (!ok || !mounted) return;
    await ref.read(repositoryProvider).setStudySubjectActive(subject['id'] as String, !active);
    await _load();
  }

  Widget _subjectCard(Map<String, Object?> subject) {
    return FutureBuilder<List<Map<String, Object?>>>(
      future: ref.read(repositoryProvider).getStudyTopics(subject['id'] as String),
      builder: (context, snapshot) {
        final topics = snapshot.data ?? const <Map<String, Object?>>[];
        final active = intValue(subject['is_active']) == 1;
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: OrvaSurface(
            padding: EdgeInsets.zero,
            child: ExpansionTile(
              leading: const CircleAvatar(backgroundColor: OrvaColors.primary100, child: Icon(Icons.school_outlined, color: OrvaColors.primary)),
              title: Text('${subject['name']}', style: Theme.of(context).textTheme.titleMedium),
              subtitle: Text('${intValue(subject['topic_count'])} assuntos · ${formatMinutes(intValue(subject['total_minutes']))} estudados'),
              childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              children: [
                if ((subject['description'] as String?)?.isNotEmpty == true)
                  Align(alignment: Alignment.centerLeft, child: Text(subject['description'] as String)),
                Wrap(
                  spacing: 4,
                  runSpacing: 2,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    TextButton.icon(onPressed: active ? () => _editTopic(subject) : null, icon: const Icon(Icons.add, size: 18), label: const Text('Assunto')),
                    TextButton.icon(onPressed: active ? () => _logSession(selectedSubject: subject['id'] as String) : null, icon: const Icon(Icons.timer_outlined, size: 18), label: const Text('Registrar')),
                    TextButton.icon(onPressed: active ? () => _planStudyBlock(subject) : null, icon: const Icon(Icons.event_outlined, size: 18), label: const Text('Planejar')),
                    PopupMenuButton<String>(
                      onSelected: (choice) {
                        if (choice == 'edit') _editSubject(subject);
                        if (choice == 'archive') _toggleArchive(subject);
                      },
                      itemBuilder: (_) => [
                        const PopupMenuItem(value: 'edit', child: Text('Editar matéria')),
                        PopupMenuItem(value: 'archive', child: Text(active ? 'Arquivar' : 'Restaurar')),
                      ],
                    ),
                  ],
                ),
                if (snapshot.connectionState == ConnectionState.waiting)
                  const LinearProgressIndicator()
                else if (topics.isEmpty)
                  const Padding(padding: EdgeInsets.all(10), child: Text('Adicione assuntos e subtópicos para organizar o aprendizado.'))
                else
                  ...topics.map((topic) {
                    final status = topic['status'] as String? ?? 'not_started';
                    final label = switch (status) { 'completed' => 'Concluído', 'in_progress' => 'Em andamento', _ => 'Não iniciado' };
                    final parent = topic['parent_name'] as String?;
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(status == 'completed' ? Icons.check_circle : status == 'in_progress' ? Icons.timelapse : Icons.circle_outlined, color: OrvaColors.primary),
                      title: Text('${parent == null ? '' : '$parent › '}${topic['name']}'),
                      subtitle: Text('$label · ${intValue(topic['session_count'])} sessões${topic['last_reviewed_at'] == null ? '' : ' · revisado ${topic['last_reviewed_at']}'}'),
                      trailing: PopupMenuButton<String>(
                        onSelected: (choice) {
                          if (choice == 'edit') _editTopic(subject, topic: topic);
                          if (choice == 'subtopic') _editTopic(subject, parent: topic);
                          if (choice == 'status') _advanceTopic(topic);
                          if (choice == 'review') _review(subject, topic);
                          if (choice == 'plan') _planStudyBlock(subject, topic: topic);
                          if (choice == 'delete') _deleteTopic(topic);
                        },
                        itemBuilder: (_) => [
                          const PopupMenuItem(value: 'edit', child: Text('Editar assunto')),
                          if (active) const PopupMenuItem(value: 'subtopic', child: Text('Adicionar subtópico')),
                          if (active) const PopupMenuItem(value: 'status', child: Text('Avançar estado')),
                          if (active) const PopupMenuItem(value: 'review', child: Text('Registrar revisão')),
                          if (active) const PopupMenuItem(value: 'plan', child: Text('Planejar sessão na rotina')),
                          const PopupMenuItem(value: 'delete', child: Text('Excluir sem histórico')),
                        ],
                      ),
                    );
                  }),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _advanceTopic(Map<String, Object?> topic) async {
    final current = topic['status'] as String? ?? 'not_started';
    final next = current == 'not_started' ? 'in_progress' : current == 'in_progress' ? 'completed' : 'not_started';
    try {
      await ref.read(repositoryProvider).saveStudyTopic(
        id: topic['id'] as String,
        subjectId: topic['subject_id'] as String,
        parentTopicId: topic['parent_topic_id'] as String?,
        name: topic['name'] as String,
        description: topic['description'] as String? ?? '',
        status: next,
        orderIndex: intValue(topic['order_index']),
      );
      await _load();
    } catch (error) { if (mounted) showOrvaError(context, error); }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: _archived ? null : FloatingActionButton.extended(
        heroTag: 'studies-create',
        onPressed: () => _logSession(),
        icon: const Icon(Icons.timer_outlined),
        label: const Text('Registrar estudo'),
      ),
      body: SafeArea(child: Column(children: [
        const OrvaPageHeader(title: 'Estudos', subtitle: 'Matérias, tópicos, revisões e sessões reais.'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: OrvaSurface(child: Row(children: [
            Expanded(child: _Metric(label: 'Estudado nesta semana', value: formatMinutes(intValue(_summary['minutes'])))),
            const SizedBox(width: 12),
            Expanded(child: _Metric(label: 'Dias com estudo', value: '${intValue(_summary['studyDays'])}')),
            const SizedBox(width: 12),
            Expanded(child: _Metric(label: 'Revisões', value: '${intValue(_summary['reviews'])}')),
          ])),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 8),
          child: Row(children: [
            Expanded(child: Text(_archived ? 'Matérias arquivadas' : 'Suas matérias', style: Theme.of(context).textTheme.titleMedium)),
            TextButton.icon(onPressed: _archived ? null : () => _editSubject(), icon: const Icon(Icons.add, size: 18), label: const Text('Nova matéria')),
            IconButton(tooltip: _archived ? 'Mostrar ativas' : 'Mostrar arquivadas', onPressed: () { setState(() => _archived = !_archived); _load(); }, icon: const Icon(Icons.archive_outlined)),
          ]),
        ),
        Expanded(child: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(onRefresh: _load, child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
              children: [
                if (_subjects.isEmpty)
                  OrvaEmptyState(
                    icon: Icons.school_outlined,
                    title: _archived ? 'Nenhuma matéria arquivada' : 'Comece pela primeira matéria',
                    message: _archived ? 'Matérias arquivadas aparecerão aqui com o histórico.' : 'Cadastre matérias, assuntos e sessões. Nenhum dado de demonstração é criado.',
                    actionLabel: _archived ? null : 'Criar matéria',
                    onAction: _archived ? null : () => _editSubject(),
                  )
                else
                  ..._subjects.map(_subjectCard),
                const SizedBox(height: 16),
                Text('Sessões recentes', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                if (_sessions.isEmpty)
                  const OrvaEmptyState(icon: Icons.history_rounded, title: 'Nenhuma sessão registrada', message: 'Registre uma sessão para formar seu histórico.', compact: true)
                else
                  ..._sessions.map((s) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: OrvaSurface(child: Row(children: [
                      const Icon(Icons.menu_book_outlined, color: OrvaColors.primary),
                      const SizedBox(width: 10),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('${s['subject_name']}', style: Theme.of(context).textTheme.titleSmall),
                        Text('${s['topic_name'] ?? 'Sem assunto'} · ${DateFormat('dd/MM/yyyy','pt_BR').format(DateTime.parse(s['session_date'] as String))}', style: Theme.of(context).textTheme.bodySmall),
                        Text(formatMinutes(intValue(s['duration_minutes'])), style: Theme.of(context).textTheme.bodyMedium),
                        if ((s['note'] as String?)?.isNotEmpty == true) Text(s['note'] as String),
                      ])),
                      IconButton(
                        tooltip: 'Editar sessão',
                        onPressed: _archived || !_subjects.any((subject) =>
                          subject['id'] == s['subject_id'] && intValue(subject['is_active']) == 1)
                            ? null
                            : () => _logSession(session: s),
                        icon: const Icon(Icons.edit_outlined),
                      ),
                      IconButton(tooltip: 'Excluir sessão', onPressed: () async {
                        final yes = await confirmAction(context, title: 'Excluir sessão?', message: 'O tempo será removido do histórico de estudo.', actionLabel: 'Excluir', destructive: true);
                        if (yes && mounted) { await ref.read(repositoryProvider).deleteStudySession(s['id'] as String); await _load(); }
                      }, icon: const Icon(Icons.delete_outline)),
                    ])),
                  )),
                if (_reviews.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text('Revisões recentes', style: Theme.of(context).textTheme.titleMedium),
                  ..._reviews.map((r) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.repeat_rounded, color: OrvaColors.information),
                    title: Text('${r['topic_name'] ?? r['subject_name']}'),
                    subtitle: Text('${r['subject_name']} · ${DateFormat('dd/MM/yyyy','pt_BR').format(DateTime.parse(r['reviewed_at'] as String))} · ${r['review_kind']}'),
                    trailing: r['confidence'] == null ? null : Text('${r['confidence']}/5'),
                  )),
                ],
              ],
            )),
        ),
      ])),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(value, style: Theme.of(context).textTheme.titleLarge?.copyWith(color: OrvaColors.primary)),
    const SizedBox(height: 3),
    Text(label, style: Theme.of(context).textTheme.bodySmall),
  ]);
}
