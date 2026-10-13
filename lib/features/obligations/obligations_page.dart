import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/database/orva_repository.dart';
import '../../core/database/obligations_repository.dart';
import '../../core/theme/orva_theme.dart';
import '../../core/widgets/orva_widgets.dart';

String _obligationTime(int minute) {
  final normalized = minute == 1440 ? 0 : minute;
  return '${(normalized ~/ 60).toString().padLeft(2, '0')}:${(normalized % 60).toString().padLeft(2, '0')}';
}

int _obligationDuration(int start, int end) => end > start ? end - start : 1440 - start + end;

class ObligationsPage extends ConsumerStatefulWidget {
  const ObligationsPage({super.key, this.initialDate});
  final DateTime? initialDate;
  @override
  ConsumerState<ObligationsPage> createState() => _ObligationsPageState();
}

class _ObligationsPageState extends ConsumerState<ObligationsPage> {
  late DateTime _date = widget.initialDate ?? DateTime.now();
  String _tab = 'schedule';
  bool _archived = false;
  bool _loading = true;
  List<Map<String, Object?>> _rules = [];
  List<Map<String, Object?>> _occurrences = [];
  List<Map<String, Object?>> _timeBlocks = [];
  List<Map<String, Object?>> _routine = [];

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final repo = ref.read(repositoryProvider);
      final values = await Future.wait<Object?>([
        repo.getObligationRules(includeInactive: true),
        repo.getObligationOccurrencesForDate(_date),
        repo.getObligationTimeBlocksForDate(_date),
        repo.getRoutineForDate(_date),
      ]);
      if (!mounted) return;
      final allRules = values[0] as List<Map<String, Object?>>;
      setState(() {
        _rules = allRules.where((r) => intValue(r['is_active']) == (_archived ? 0 : 1)).toList();
        _occurrences = values[1] as List<Map<String, Object?>>;
        _timeBlocks = values[2] as List<Map<String, Object?>>;
        _routine = values[3] as List<Map<String, Object?>>;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _loading = false);
      showOrvaError(context, error);
    }
  }

  Future<void> _changeDate(int days) async {
    setState(() => _date = DateTime(_date.year, _date.month, _date.day + days));
    await _load();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(context: context, initialDate: _date, firstDate: DateTime(2000), lastDate: DateTime(2100));
    if (picked == null || !mounted) return;
    setState(() => _date = picked);
    await _load();
  }

  Future<void> _editRule({
    Map<String, Object?>? rule,
    String? suggestionName,
    String suggestionCategory = 'Pessoal',
    int? suggestionStart,
    int? suggestionEnd,
  }) async {
    final name = TextEditingController(text: rule?['name'] as String? ?? suggestionName ?? '');
    final category = TextEditingController(text: rule?['category'] as String? ?? suggestionCategory);
    var recurrence = rule?['recurrence'] as String? ?? 'weekly';
    var priority = rule?['priority'] as String? ?? 'normal';
    var start = DateTime.tryParse(rule?['start_date'] as String? ?? '') ?? _date;
    var endDate = DateTime.tryParse(rule?['end_date'] as String? ?? '');
    var startMinute = (rule?['start_minute'] as num?)?.toInt() ?? suggestionStart ?? 9 * 60;
    var endMinute = (rule?['end_minute'] as num?)?.toInt() ?? suggestionEnd ?? 10 * 60;
    Set<int> days = {};
    try {
      final raw = rule?['weekdays_json'] as String?;
      if (raw != null) days = (jsonDecode(raw) as List).whereType<num>().map((n) => n.toInt()).toSet();
    } catch (_) {}
    if (days.isEmpty) days = {_date.weekday};
    if (!mounted) { name.dispose(); category.dispose(); return; }
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialog) => StatefulBuilder(builder: (context, setDialog) => AlertDialog(
        title: Text(rule == null ? 'Nova obrigação recorrente' : 'Editar obrigação'),
        content: SizedBox(width: 480, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: name, autofocus: true, maxLength: 120, decoration: const InputDecoration(labelText: 'Nome *')),
          const SizedBox(height: 8),
          TextField(controller: category, maxLength: 80, decoration: const InputDecoration(labelText: 'Categoria')),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: recurrence,
            decoration: const InputDecoration(labelText: 'Recorrência'),
            items: const [
              DropdownMenuItem(value: 'once', child: Text('Uma vez')),
              DropdownMenuItem(value: 'daily', child: Text('Diariamente')),
              DropdownMenuItem(value: 'weekly', child: Text('Dias específicos da semana')),
            ],
            onChanged: (v) => setDialog(() => recurrence = v ?? 'weekly'),
          ),
          if (recurrence == 'weekly') ...[
            const SizedBox(height: 8),
            Align(alignment: Alignment.centerLeft, child: Text('Dias da semana', style: Theme.of(context).textTheme.labelLarge)),
            Wrap(spacing: 4, children: [
              for (final day in const [1,2,3,4,5,6,7])
                FilterChip(
                  label: Text(['Seg','Ter','Qua','Qui','Sex','Sáb','Dom'][day-1]),
                  selected: days.contains(day),
                  onSelected: (on) => setDialog(() { if (on) { days.add(day); } else { days.remove(day); } }),
                ),
            ]),
          ],
          OutlinedButton.icon(
            onPressed: () async {
              final date = await showDatePicker(context: context, initialDate: start, firstDate: DateTime(2000), lastDate: DateTime(2100));
              if (date != null) setDialog(() => start = date);
            },
            icon: const Icon(Icons.calendar_today_outlined),
            label: Text('Começa em: ${DateFormat('dd/MM/yyyy','pt_BR').format(start)}'),
          ),
          if (recurrence != 'once') ...[
            TextButton.icon(
              onPressed: () async {
                final date = await showDatePicker(context: context, initialDate: endDate ?? start.add(const Duration(days: 30)), firstDate: start, lastDate: DateTime(2100));
                if (date != null) setDialog(() => endDate = date);
              },
              icon: const Icon(Icons.event_busy_outlined),
              label: Text(endDate == null ? 'Sem data final' : 'Termina em: ${DateFormat('dd/MM/yyyy','pt_BR').format(endDate!)}'),
            ),
            if (endDate != null) Align(alignment: Alignment.centerLeft, child: TextButton(onPressed: () => setDialog(() => endDate = null), child: const Text('Remover data final'))),
          ],
          const Divider(height: 20),
          OutlinedButton.icon(
            onPressed: () async {
              final time = await showTimePicker(context: context, initialTime: TimeOfDay(hour: startMinute ~/ 60, minute: startMinute % 60));
              if (time != null) setDialog(() => startMinute = time.hour * 60 + time.minute);
            },
            icon: const Icon(Icons.play_arrow_outlined),
            label: Text('Início: ${_obligationTime(startMinute)}'),
          ),
          OutlinedButton.icon(
            onPressed: () async {
              final time = await showTimePicker(context: context, initialTime: TimeOfDay(hour: endMinute ~/ 60, minute: endMinute % 60));
              if (time != null) setDialog(() => endMinute = time.hour * 60 + time.minute);
            },
            icon: const Icon(Icons.stop_outlined),
            label: Text('Fim: ${_obligationTime(endMinute)}${endMinute < startMinute ? ' (+1 dia)' : ''}'),
          ),
          if (endMinute < startMinute)
            Align(alignment: Alignment.centerLeft, child: Text('Este intervalo atravessa a meia-noite. A ocorrência fica vinculada à data em que começa.', style: Theme.of(context).textTheme.bodySmall)),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: priority,
            decoration: const InputDecoration(labelText: 'Prioridade'),
            items: const [
              DropdownMenuItem(value: 'low', child: Text('Baixa')),
              DropdownMenuItem(value: 'normal', child: Text('Normal')),
              DropdownMenuItem(value: 'high', child: Text('Alta')),
            ],
            onChanged: (v) => setDialog(() => priority = v ?? 'normal'),
          ),
        ]))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialog, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () {
            if (name.text.trim().isEmpty || startMinute == endMinute) { showOrvaMessage(dialog, 'Informe um nome e horários diferentes.'); return; }
            if (recurrence == 'weekly' && days.isEmpty) { showOrvaMessage(dialog, 'Selecione ao menos um dia da semana.'); return; }
            if (endDate != null && endDate!.isBefore(start)) { showOrvaMessage(dialog, 'A data final deve ser posterior ao início.'); return; }
            Navigator.pop(dialog, true);
          }, child: const Text('Salvar regra')),
        ],
      )),
    );
    if (ok == true && mounted) {
      try {
        await ref.read(repositoryProvider).saveObligationRule(
          id: rule?['id'] as String?,
          name: name.text,
          category: category.text.trim().isEmpty ? 'Pessoal' : category.text,
          startMinute: startMinute,
          endMinute: endMinute,
          recurrence: recurrence,
          weekdays: recurrence == 'weekly' ? days.toList() : const [],
          startDate: start,
          endDate: recurrence == 'once' ? null : endDate,
          priority: priority,
        );
        await _load();
      } catch (error) { if (mounted) showOrvaError(context, error); }
    }
    name.dispose();
    category.dispose();
  }

  Future<void> _ruleActive(Map<String, Object?> rule) async {
    final active = intValue(rule['is_active']) == 1;
    final ok = await confirmAction(context, title: active ? 'Suspender obrigação?' : 'Reativar obrigação?', message: 'Ocorrências já concluídas e seu histórico serão preservados.', actionLabel: active ? 'Suspender' : 'Reativar');
    if (!ok || !mounted) return;
    try {
      await ref.read(repositoryProvider).setObligationRuleActive(rule['id'] as String, !active);
      await _load();
    } catch (error) { if (mounted) showOrvaError(context, error); }
  }

  Future<void> _exception(Map<String, Object?> occurrence, {required String action}) async {
    final date = DateTime.parse(occurrence['occurrence_date'] as String);
    final ruleId = occurrence['rule_id'] as String;
    if (action == 'skip') {
      final ok = await confirmAction(context, title: 'Pular esta ocorrência?', message: 'Somente esta data será dispensada. A regra recorrente e as outras datas continuam iguais.', actionLabel: 'Pular data');
      if (!ok || !mounted) return;
      try {
        await ref.read(repositoryProvider).saveObligationException(
          ruleId: ruleId,
          occurrenceDate: date,
          action: 'skip',
          note: 'Ocorrência dispensada pelo usuário.',
        );
        await _load();
      } catch (error) { if (mounted) showOrvaError(context, error); }
      return;
    }

    if (action == 'clear') {
      final ok = await confirmAction(context, title: 'Remover exceção desta data?', message: 'A ocorrência voltará a seguir a regra recorrente, exceto se já tiver sido concluída.', actionLabel: 'Remover exceção');
      if (!ok || !mounted) return;
      await ref.read(repositoryProvider).clearObligationException(ruleId, date);
      await _load();
      return;
    }

    final name = TextEditingController(text: occurrence['name_snapshot'] as String? ?? '');
    final category = TextEditingController(text: occurrence['category_snapshot'] as String? ?? '');
    var startMinute = (occurrence['start_minute'] as num).toInt();
    var endMinute = (occurrence['end_minute'] as num).toInt();
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialog) => StatefulBuilder(builder: (context, setDialog) => AlertDialog(
        title: Text('Alterar apenas ${DateFormat('dd/MM','pt_BR').format(date)}'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: name, decoration: const InputDecoration(labelText: 'Nome nesta data *')),
          const SizedBox(height: 8),
          TextField(controller: category, decoration: const InputDecoration(labelText: 'Categoria nesta data')),
          OutlinedButton.icon(onPressed: () async {
            final t = await showTimePicker(context: context, initialTime: TimeOfDay(hour: startMinute ~/ 60, minute: startMinute % 60));
            if (t != null) setDialog(() => startMinute = t.hour * 60 + t.minute);
          }, icon: const Icon(Icons.play_arrow_outlined), label: Text('Início: ${_obligationTime(startMinute)}')),
          OutlinedButton.icon(onPressed: () async {
            final t = await showTimePicker(context: context, initialTime: TimeOfDay(hour: endMinute ~/ 60, minute: endMinute % 60));
            if (t != null) setDialog(() => endMinute = t.hour * 60 + t.minute);
          }, icon: const Icon(Icons.stop_outlined), label: Text('Fim: ${_obligationTime(endMinute)}${endMinute < startMinute ? ' (+1 dia)' : ''}')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialog, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () {
            if (name.text.trim().isEmpty || startMinute == endMinute) { showOrvaMessage(dialog, 'Informe um nome e horários diferentes.'); return; }
            Navigator.pop(dialog, true);
          }, child: const Text('Salvar exceção')),
        ],
      )),
    );
    if (ok == true && mounted) {
      try {
        await ref.read(repositoryProvider).saveObligationException(
          ruleId: ruleId,
          occurrenceDate: date,
          action: 'override',
          overrideName: name.text,
          overrideCategory: category.text,
          overrideStartMinute: startMinute,
          overrideEndMinute: endMinute,
          note: 'Horário alterado somente para esta data.',
        );
        await _load();
      } catch (error) { if (mounted) showOrvaError(context, error); }
    }
    name.dispose();
    category.dispose();
  }

  Future<void> _toggleCompleted(Map<String, Object?> occurrence, bool completed) async {
    try {
      await ref.read(repositoryProvider).setObligationOccurrenceCompleted(occurrence['id'] as String, completed);
      await _load();
    } catch (error) { if (mounted) showOrvaError(context, error); }
  }

  Future<void> _history(Map<String, Object?> rule) async {
    final history = await ref.read(repositoryProvider).getObligationHistory(rule['id'] as String);
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text('Histórico · ${rule['name']}'),
        content: SizedBox(width: 480, child: history.isEmpty
          ? const Text('Ainda não há ocorrências visualizadas ou registradas.')
          : ListView.separated(
              shrinkWrap: true,
              itemCount: history.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (_, index) {
                final occurrence = history[index];
                final status = occurrence['status'] as String;
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(DateFormat('dd/MM/yyyy','pt_BR').format(DateTime.parse(occurrence['occurrence_date'] as String))),
                  subtitle: Text('${_obligationTime(intValue(occurrence['start_minute']))}–${_obligationTime(intValue(occurrence['end_minute']))}${intValue(occurrence['ends_next_day']) == 1 ? ' (+1 dia)' : ''}'),
                  trailing: Text(switch (status) { 'completed' => 'Concluída', 'skipped' => 'Dispensada', _ => 'Planejada' }),
                );
              },
            )),
        actions: [TextButton(onPressed: () => Navigator.pop(dialog), child: const Text('Fechar'))],
      ),
    );
  }

  String _recurrenceLabel(Map<String, Object?> rule) {
    final recurrence = rule['recurrence'] as String? ?? 'weekly';
    if (recurrence == 'once') return 'Uma vez';
    if (recurrence == 'daily') return 'Diariamente';
    try {
      final days = (jsonDecode(rule['weekdays_json'] as String) as List).whereType<num>().map((v) => v.toInt()).toList();
      const names = ['Seg','Ter','Qua','Qui','Sex','Sáb','Dom'];
      return days.map((d) => names[d - 1]).join(', ');
    } catch (_) { return 'Dias selecionados'; }
  }

  Widget _ruleCard(Map<String, Object?> rule) {
    final active = intValue(rule['is_active']) == 1;
    final start = intValue(rule['start_minute']);
    final end = intValue(rule['end_minute']);
    final wraps = end < start;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: OrvaSurface(child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(width: 44, height: 44, decoration: BoxDecoration(color: OrvaColors.information.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.repeat_rounded, color: OrvaColors.information)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${rule['name']}', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 3),
          Text('${rule['category']} · ${_obligationTime(start)}–${_obligationTime(end)}${wraps ? ' (+1 dia)' : ''}', style: Theme.of(context).textTheme.bodyMedium),
          Text('${_recurrenceLabel(rule)} · ${formatMinutes(_obligationDuration(start,end))} por ocorrência', style: Theme.of(context).textTheme.bodySmall),
          if (rule['end_date'] != null) Text('Até ${DateFormat('dd/MM/yyyy','pt_BR').format(DateTime.parse(rule['end_date'] as String))}', style: Theme.of(context).textTheme.bodySmall),
          if (rule['priority'] == 'high') const Text('Prioridade alta', style: TextStyle(color: OrvaColors.terracotta)),
        ])),
        PopupMenuButton<String>(
          onSelected: (choice) {
            if (choice == 'edit') _editRule(rule: rule);
            if (choice == 'toggle') _ruleActive(rule);
            if (choice == 'history') _history(rule);
          },
          itemBuilder: (_) => [
            const PopupMenuItem(value: 'edit', child: Text('Editar regra')),
            PopupMenuItem(value: 'toggle', child: Text(active ? 'Suspender' : 'Reativar')),
            const PopupMenuItem(value: 'history', child: Text('Ver histórico')),
          ],
        ),
      ])),
    );
  }

  List<String> _conflicts() {
    final messages = <String>[];
    for (final obligation in _timeBlocks) {
      final aStart = intValue(obligation['start_minute']);
      final aEnd = intValue(obligation['end_minute']);
      for (final routine in _routine) {
        final bStart = intValue(routine['start_minute']);
        final bEnd = intValue(routine['end_minute']);
        if (aStart < bEnd && bStart < aEnd) {
          final text = '${obligation['title']} × ${routine['title']}';
          if (!messages.contains(text)) messages.add(text);
        }
      }
    }
    for (var i=0;i<_timeBlocks.length;i++) {
      for (var j=i+1;j<_timeBlocks.length;j++) {
        final a=_timeBlocks[i]; final b=_timeBlocks[j];
        if(intValue(a['start_minute'])<intValue(b['end_minute']) &&
           intValue(b['start_minute'])<intValue(a['end_minute'])) {
          final text='${a['title']} × ${b['title']}';
          if(!messages.contains(text))messages.add(text);
        }
      }
    }
    return messages;
  }

  @override
  Widget build(BuildContext context) {
    final isToday = DateUtils.isSameDay(_date, DateTime.now());
    final conflicts = _conflicts();
    return Scaffold(
      floatingActionButton: _tab == 'rules' && !_archived
          ? FloatingActionButton.extended(onPressed: () => _editRule(), icon: const Icon(Icons.add), label: const Text('Nova obrigação'))
          : null,
      body: SafeArea(child: Column(children: [
        const OrvaPageHeader(title: 'Obrigações recorrentes', subtitle: 'Configure necessidades fixas uma vez e ajuste exceções por data. Nada é ativado sem sua escolha.'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: OrvaSurface(child: Row(children: [
            IconButton(tooltip: 'Dia anterior', onPressed: () => _changeDate(-1), icon: const Icon(Icons.chevron_left)),
            Expanded(child: TextButton.icon(onPressed: _pickDate, icon: const Icon(Icons.calendar_today_outlined), label: Text(isToday ? 'Hoje · ${DateFormat('dd/MM/yyyy','pt_BR').format(_date)}' : DateFormat('EEEE, dd/MM/yyyy','pt_BR').format(_date), textAlign: TextAlign.center))),
            IconButton(tooltip: 'Próximo dia', onPressed: () => _changeDate(1), icon: const Icon(Icons.chevron_right)),
          ])),
        ),
        const SizedBox(height: 10),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'schedule', label: Text('Dia e ocorrências')),
              ButtonSegment(value: 'rules', label: Text('Regras')),
            ],
            selected: {_tab},
            showSelectedIcon: false,
            onSelectionChanged: (values) => setState(() => _tab = values.first),
          ),
        ),
        if (_tab == 'rules')
          Padding(
            padding: const EdgeInsets.fromLTRB(20,8,20,0),
            child: Row(children: [
              Expanded(child: Text(_archived ? 'Regras suspensas' : 'Regras ativas', style: Theme.of(context).textTheme.titleSmall)),
              TextButton.icon(onPressed: () { setState(() => _archived = !_archived); _load(); }, icon: const Icon(Icons.archive_outlined, size:18), label: Text(_archived ? 'Ativas' : 'Suspensas')),
            ]),
          ),
        const SizedBox(height: 8),
        Expanded(child: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(onRefresh: _load, child: ListView(
              padding: const EdgeInsets.fromLTRB(20,4,20,104),
              children: _tab == 'rules' ? [
                if (!_archived && _rules.isEmpty)
                  const OrvaEmptyState(icon: Icons.repeat_rounded, title: 'Sem obrigações configuradas', message: 'Escolha abaixo uma sugestão ou crie sua própria regra. Nada será ativado automaticamente.', compact: true),
                if (!_archived) ...[
                  Text('Sugestões opcionais', style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 6),
                  Wrap(spacing:8,runSpacing:4,children:[
                    ActionChip(label:const Text('Sono 22:30–07:30'),avatar:const Icon(Icons.bedtime_outlined,size:18),onPressed:()=>_editRule(suggestionName:'Sono',suggestionCategory:'Descanso',suggestionStart:22*60+30,suggestionEnd:7*60+30)),
                    ActionChip(label:const Text('Escola 08:00–13:00'),avatar:const Icon(Icons.school_outlined,size:18),onPressed:()=>_editRule(suggestionName:'Escola',suggestionCategory:'Estudos',suggestionStart:8*60,suggestionEnd:13*60)),
                    ActionChip(label:const Text('Refeição'),avatar:const Icon(Icons.restaurant_outlined,size:18),onPressed:()=>_editRule(suggestionName:'Refeição',suggestionCategory:'Alimentação',suggestionStart:12*60,suggestionEnd:12*60+30)),
                  ]),
                  const SizedBox(height:14),
                ],
                ..._rules.map(_ruleCard),
              ] : [
                Text('Planejamento do dia', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height:4),
                Text('As ocorrências marcadas são planejadas; só as que você confirmar são registradas como concluídas.', style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height:10),
                if (_timeBlocks.isEmpty)
                  const OrvaEmptyState(icon: Icons.schedule_outlined, title: 'Nenhuma obrigação neste dia', message: 'Ative uma regra ou escolha uma data diferente.', compact: true)
                else
                  ..._timeBlocks.map((block) => Padding(
                    padding: const EdgeInsets.only(bottom:6),
                    child: OrvaSurface(child: Row(children:[
                      Container(width:4,height:42,decoration:BoxDecoration(color:OrvaColors.information,borderRadius:BorderRadius.circular(4))),
                      const SizedBox(width:10),
                      SizedBox(width:94,child:Text('${_obligationTime(intValue(block['start_minute']))}–${_obligationTime(intValue(block['end_minute']))}',style:Theme.of(context).textTheme.labelLarge)),
                      Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                        Text('${block['title']}',style:Theme.of(context).textTheme.titleSmall),
                        Text('${block['category']} · planejamento',style:Theme.of(context).textTheme.bodySmall),
                      ])),
                    ])),
                  )),
                if (conflicts.isNotEmpty) ...[
                  const SizedBox(height:10),
                  OrvaSurface(color:Theme.of(context).brightness==Brightness.dark?OrvaColors.darkSubtle:OrvaColors.accent100,child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                    Row(children:[const Icon(Icons.warning_amber_rounded,color:OrvaColors.terracotta),const SizedBox(width:8),Expanded(child:Text('Sobreposições encontradas',style:Theme.of(context).textTheme.titleSmall))]),
                    const SizedBox(height:8),
                    ...conflicts.map((c)=>Padding(padding:const EdgeInsets.only(bottom:4),child:Text('• $c'))),
                    Text('O total de tempo será contado pela união dos intervalos, não pela soma duplicada.',style:Theme.of(context).textTheme.bodySmall),
                  ])),
                ],
                const SizedBox(height:18),
                Text('Ocorrências que começam nesta data', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height:8),
                if(_occurrences.isEmpty)
                  const OrvaEmptyState(icon:Icons.event_available_outlined,title:'Nenhuma ocorrência iniciada hoje',message:'Regras diárias e semanais gerarão ocorrências quando corresponderem à data.',compact:true)
                else
                  ..._occurrences.map((occurrence){
                    final status=occurrence['status'] as String? ?? 'planned';
                    final skipped=status=='skipped';
                    final completed=status=='completed';
                    final wraps=intValue(occurrence['ends_next_day'])==1;
                    final exception=occurrence['exception_action'] as String?;
                    return Padding(
                      padding:const EdgeInsets.only(bottom:8),
                      child:OrvaSurface(child:Row(crossAxisAlignment:CrossAxisAlignment.start,children:[
                        Checkbox(value:completed,onChanged:skipped?null:(value)=>_toggleCompleted(occurrence,value??false)),
                        const SizedBox(width:4),
                        Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                          Text('${occurrence['name_snapshot']}',style:Theme.of(context).textTheme.titleSmall?.copyWith(decoration:completed?TextDecoration.lineThrough:null)),
                          const SizedBox(height:3),
                          Text('${occurrence['category_snapshot']} · ${_obligationTime(intValue(occurrence['start_minute']))}–${_obligationTime(intValue(occurrence['end_minute']))}${wraps?' (+1 dia)':''}',style:Theme.of(context).textTheme.bodySmall),
                          Text(skipped?'Dispensada nesta data':completed?'Concluída por você':'Planejada',style:Theme.of(context).textTheme.bodySmall),
                        ])),
                        PopupMenuButton<String>(
                          onSelected:(choice)=>_exception(occurrence,action:choice),
                          itemBuilder:(_)=>[
                            if(!skipped&&!completed)const PopupMenuItem(value:'skip',child:Text('Pular esta data')),
                            if(!skipped&&!completed)const PopupMenuItem(value:'override',child:Text('Alterar apenas esta data')),
                            if(exception!=null&&!completed)const PopupMenuItem(value:'clear',child:Text('Remover exceção')),
                          ],
                        ),
                      ])),
                    );
                  }),
              ],
            )),
        ),
      ])),
    );
  }
}
