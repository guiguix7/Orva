import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/database/orva_repository.dart';
import '../../core/domain/orva_calculations.dart';
import '../../core/theme/orva_theme.dart';
import '../../core/widgets/orva_widgets.dart';
import '../checklists/checklists_page.dart';
import '../goals/goals_page.dart';
import '../hobbies/hobbies_page.dart';
import '../journal/journal_page.dart';
import '../notes/notes_page.dart';
import '../routine/routine_page.dart';
import '../quotes/quotes_data.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key, required this.onNavigate, required this.refreshSignal});
  final ValueChanged<int> onNavigate;
  final int refreshSignal;

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  bool _loading = true;
  Timer? _homeClock;
  String? _userName;
  String? _focus;
  bool _focusCompleted = false;
  String? _loadedDateKey;
  Map<String, Object?> _summary = {};
  List<Map<String, Object?>> _goals = [];
  List<Map<String, Object?>> _items = [];
  List<Map<String, Object?>> _routine = [];
  List<Map<String, Object?>> _hobbies = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
    // Keep the greeting and current-block marker live while Home remains mounted.
    _homeClock = Timer.periodic(const Duration(minutes: 1), (_) {
      if (!mounted) return;
      final today = ref.read(repositoryProvider).dateKey(DateTime.now());
      if (!_loading && _loadedDateKey != today) {
        _load();
      } else {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _homeClock?.cancel();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant HomePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshSignal != widget.refreshSignal) {
      _load();
      return;
    }
    // Home can stay mounted in IndexedStack through midnight. Refresh the
    // date-scoped focus, checklist and schedule as soon as the day changes.
    final today = ref.read(repositoryProvider).dateKey(DateTime.now());
    if (_loadedDateKey != today) _load();
  }

  Future<void> _openPage(Widget page) async {
    await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));
    if (mounted) await _load();
  }

  Future<void> _load() async {
    try {
      final repo = ref.read(repositoryProvider);
      final now = DateTime.now();
      final values = await Future.wait<Object?>([
        repo.getSetting('user_name'),
        repo.getSetting('focus_${repo.dateKey(now)}'),
        repo.getSetting('focus_done_${repo.dateKey(now)}'),
        repo.getTodaySummary(now),
        repo.getGoals(status: 'active'),
        repo.getTodayOccurrenceItems(now),
        repo.getRoutineForDate(now),
        repo.getWeeklyHobbyMinutes(date: now),
      ]);
      if (!mounted) return;
      setState(() {
        _loadedDateKey = repo.dateKey(now);
        _userName = (values[0] as String?)?.trim();
        _focus = (values[1] as String?)?.trim();
        _focusCompleted = (values[2] as String?) == '1';
        _summary = values[3] as Map<String, Object?>;
        _goals = (values[4] as List<Map<String, Object?>>).take(3).toList();
        _items = (values[5] as List<Map<String, Object?>>).take(5).toList();
        _routine = values[6] as List<Map<String, Object?>>;
        _hobbies = (values[7] as List<Map<String, Object?>>).take(3).toList();
        _loading = false;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() { _loading = false; _error = '$error'; });
    }
  }

  Future<void> _quickAction() async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Criar algo novo', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 14),
            _QuickActionTile(icon: Icons.check_circle_outline, title: 'Tarefa de hoje', subtitle: 'Adicionar um item ao checklist do dia', onTap: () => Navigator.pop(context, 'task')),
            _QuickActionTile(icon: Icons.flag_outlined, title: 'Meta', subtitle: 'Transformar um objetivo em plano', onTap: () => Navigator.pop(context, 'goal')),
            _QuickActionTile(icon: Icons.edit_note_outlined, title: 'Nota', subtitle: 'Guardar uma ideia ou informação', onTap: () => Navigator.pop(context, 'note')),
            _QuickActionTile(icon: Icons.menu_book_outlined, title: 'Entrada no diário', subtitle: 'Registrar algo sobre o seu dia', onTap: () => Navigator.pop(context, 'journal')),
            _QuickActionTile(icon: Icons.schedule_outlined, title: 'Bloco de rotina', subtitle: 'Planejar um período de tempo', onTap: () => Navigator.pop(context, 'routine')),
            _QuickActionTile(icon: Icons.sports_esports_outlined, title: 'Hobby', subtitle: 'Acompanhar tempo de uma atividade', onTap: () => Navigator.pop(context, 'hobby')),
          ]),
        ),
      ),
    );
    if (!mounted || choice == null) return;
    try {
      switch (choice) {
        case 'task':
          await showAddTodayTaskDialog(context, ref);
          break;
        case 'goal':
          await showGoalEditor(context, ref);
          break;
        case 'note':
          await showNoteEditor(context, ref);
          break;
        case 'journal':
          await showJournalEditor(context, ref, DateTime.now());
          break;
        case 'routine':
          await showRoutineEditor(context, ref);
          break;
        case 'hobby':
          await showHobbyEditor(context, ref);
          break;
      }
      await _load();
    } catch (error) {
      if (mounted) showOrvaError(context, error);
    }
  }

  Future<void> _editFocus() async {
    final controller = TextEditingController(text: _focus ?? '');
    final repo = ref.read(repositoryProvider);
    final value = await showDialog<String?>(context: context, builder: (dialogContext) => AlertDialog(
      title: const Text('Foco do dia'),
      content: TextField(controller: controller, autofocus: true, maxLength: 120, textCapitalization: TextCapitalization.sentences, decoration: const InputDecoration(labelText: 'Prioridade opcional', hintText: 'Qual é o ponto mais importante de hoje?')),
      actions: [
        TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancelar')),
        TextButton(onPressed: () => Navigator.pop(dialogContext, ''), child: const Text('Limpar')),
        FilledButton(onPressed: () => Navigator.pop(dialogContext, controller.text.trim()), child: const Text('Salvar')),
      ],
    ));
    controller.dispose();
    if (value == null || !mounted) return;
    final dateKey = repo.dateKey(DateTime.now());
    final key = 'focus_$dateKey';
    final completedKey = 'focus_done_$dateKey';
    if (value.isEmpty) {
      await repo.execute(
        'DELETE FROM settings WHERE setting_key IN (?, ?)',
        [key, completedKey],
      );
    } else {
      await repo.setSetting(key, value);
      // Alterar o foco cria uma nova prioridade a concluir.
      if (value != (_focus ?? '')) await repo.setSetting(completedKey, '0');
    }
    await _load();
  }

  Future<void> _toggleFocusCompleted() async {
    if (_focus?.isNotEmpty != true) return;
    final repo = ref.read(repositoryProvider);
    final key = 'focus_done_${repo.dateKey(DateTime.now())}';
    final next = !_focusCompleted;
    try {
      await repo.setSetting(key, next ? '1' : '0');
      if (mounted) setState(() => _focusCompleted = next);
    } catch (error) {
      if (mounted) showOrvaError(context, error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final nameState = ref.watch(userNameProvider);
    final currentName = nameState.hasValue ? nameState.value : _userName;
    final now = DateTime.now();
    final date = DateFormat('EEEE, d MMMM', 'pt_BR').format(now);
    final greeting = greetingForHour(now.hour);
    final name = currentName == null || currentName.isEmpty ? '' : ', $currentName';
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? ListView(children: [OrvaEmptyState(icon: Icons.error_outline, title: 'Não foi possível carregar', message: _error!, actionLabel: 'Tentar novamente', onAction: _load)])
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
                      children: [
                        Row(children: [
                          Container(width: 42, height: 42, decoration: BoxDecoration(color: OrvaColors.primary, borderRadius: BorderRadius.circular(14)), child: const Icon(Icons.spa_outlined, color: Colors.white, size: 24)),
                          const SizedBox(width: 10),
                          Text('orva', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 22, letterSpacing: -0.8)),
                          const Spacer(),
                          IconButton.filledTonal(
                            tooltip: 'Criar',
                            onPressed: _quickAction,
                            icon: const Icon(Icons.add_rounded),
                          ),
                          const SizedBox(width: 4),
                          IconButton(tooltip: 'Mais opções', onPressed: () => widget.onNavigate(3), icon: const Icon(Icons.tune_rounded)),
                        ]),
                        const SizedBox(height: 28),
                        Text(greeting + name, style: Theme.of(context).textTheme.displaySmall),
                        const SizedBox(height: 6),
                        Text(_capitalize(date), style: Theme.of(context).textTheme.bodyMedium),
                        const SizedBox(height: 28),
                        _FocusCard(
                          focus: _focus,
                          completed: _focusCompleted,
                          onEditFocus: _editFocus,
                          onToggleCompleted: _toggleFocusCompleted,
                        ),
                        const SizedBox(height: 26),
                        OrvaSectionHeader(title: 'Seu dia, em números'),
                        const SizedBox(height: 12),
                        _ProgressSummary(summary: _summary),
                        const SizedBox(height: 28),
                        OrvaSectionHeader(title: 'Checklist de hoje', actionLabel: 'Ver todos', onAction: () => widget.onNavigate(1)),
                        const SizedBox(height: 12),
                        if (_items.isEmpty)
                          const OrvaSurface(child: OrvaEmptyState(icon: Icons.checklist_rounded, title: 'O dia está em aberto', message: 'Crie um checklist e escolha o que deseja concluir hoje.', compact: true))
                        else
                          OrvaSurface(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Column(children: [
                              for (var i = 0; i < _items.length; i++) ...[
                                _HomeChecklistItem(item: _items[i], onChanged: (checked) async {
                                  await ref.read(repositoryProvider).setOccurrenceItemCompleted(_items[i]['id'] as String, checked);
                                  await _load();
                                }),
                                if (i < _items.length - 1) const Divider(height: 1, indent: 54, endIndent: 14),
                              ],
                              if ((_summary['checklistTotal'] as int? ?? 0) > _items.length)
                                Padding(padding: const EdgeInsets.fromLTRB(16, 8, 16, 12), child: Align(alignment: Alignment.centerLeft, child: Text('Mais ${(_summary['checklistTotal'] as int) - _items.length} itens no checklist', style: Theme.of(context).textTheme.bodySmall))),
                            ]),
                          ),
                        const SizedBox(height: 28),
                        OrvaSectionHeader(title: 'Metas ativas', actionLabel: 'Ver metas', onAction: () => widget.onNavigate(2)),
                        const SizedBox(height: 12),
                        if (_goals.isEmpty)
                          OrvaSurface(child: OrvaEmptyState(icon: Icons.flag_outlined, title: 'Ainda sem metas', message: 'Defina o que você quer construir, no seu ritmo.', actionLabel: 'Criar minha primeira meta', onAction: () async { await showGoalEditor(context, ref); await _load(); }, compact: true))
                        else
                          ..._goals.map((goal) => Padding(padding: const EdgeInsets.only(bottom: 10), child: _GoalMiniCard(goal: goal, isDark: isDark, onTap: () => widget.onNavigate(2)))),
                        const SizedBox(height: 18),
                        OrvaSectionHeader(title: 'Rotina de hoje', actionLabel: 'Abrir rotina', onAction: () => _openPage(const RoutinePage())),
                        const SizedBox(height: 12),
                        if (_routine.isEmpty)
                          OrvaSurface(child: OrvaEmptyState(icon: Icons.schedule_outlined, title: 'Sem blocos planejados', message: 'Organize o tempo do dia com atividades e horários definidos.', actionLabel: 'Adicionar atividade', onAction: () async { await showRoutineEditor(context, ref); await _load(); }, compact: true))
                        else
                          OrvaSurface(padding: const EdgeInsets.all(16), child: Column(children: [
                            for (var i = 0; i < _routine.take(3).length; i++) ...[
                              _RoutineMiniRow(block: _routine[i]),
                              if (i < _routine.take(3).length - 1) const SizedBox(height: 16),
                            ],
                          ])),
                        const SizedBox(height: 28),
                        OrvaSectionHeader(title: 'Tempo planejado', actionLabel: 'Ver rotina', onAction: () => _openPage(const RoutinePage())),
                        const SizedBox(height: 12),
                        _TimeSummaryCard(summary: _summary, isDark: isDark),
                        const SizedBox(height: 12),
                        _DayAllocationCard(summary: _summary, routine: _routine),
                        const SizedBox(height: 28),
                        OrvaSectionHeader(title: 'Hobbies nesta semana', actionLabel: 'Ver hobbies', onAction: () => _openPage(const HobbiesPage())),
                        const SizedBox(height: 12),
                        if (_hobbies.isEmpty)
                          const OrvaSurface(child: OrvaEmptyState(icon: Icons.sports_esports_outlined, title: 'Seu tempo livre também importa', message: 'Registre hobbies para acompanhar o tempo que realmente dedica a eles.', compact: true))
                        else
                          OrvaSurface(child: Column(children: [
                            for (var i = 0; i < _hobbies.length; i++) ...[
                              _HobbyMiniRow(hobby: _hobbies[i]),
                              if (i < _hobbies.length - 1) const Divider(height: 22),
                            ],
                          ])),
                        const SizedBox(height: 28),
                        const _DailyQuoteCard(),
                      ],
                    ),
        ),
      ),
    );
  }
}

String _capitalize(String value) => value.isEmpty ? value : '${value[0].toUpperCase()}${value.substring(1)}';

class _FocusCard extends StatelessWidget {
  const _FocusCard({
    required this.focus,
    required this.completed,
    required this.onEditFocus,
    required this.onToggleCompleted,
  });

  final String? focus;
  final bool completed;
  final VoidCallback onEditFocus;
  final VoidCallback onToggleCompleted;

  @override
  Widget build(BuildContext context) {
    final hasFocus = focus?.trim().isNotEmpty == true;
    return OrvaSurface(
      color: Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF24332F)
          : OrvaColors.primary900,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.spa_outlined, color: Color(0xFFB9D6D0), size: 20),
            const SizedBox(width: 8),
            Text(
              'FOCO DO DIA',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: const Color(0xFFB9D6D0),
                    letterSpacing: 1.2,
                    fontSize: 11,
                  ),
            ),
            const Spacer(),
            if (hasFocus)
              IconButton(
                onPressed: onEditFocus,
                tooltip: 'Editar foco',
                icon: const Icon(Icons.edit_outlined,
                    size: 18, color: Color(0xFFD7E4E1)),
              ),
          ]),
          const SizedBox(height: 8),
          Text(
            hasFocus
                ? focus!
                : 'Qual é a principal coisa que você quer realizar hoje?',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Colors.white,
                  fontSize: 23,
                  decoration: completed ? TextDecoration.lineThrough : null,
                ),
          ),
          const SizedBox(height: 7),
          Text(
            hasFocus
                ? (completed
                    ? 'Foco concluído. Você pode reabri-lo se precisar.'
                    : 'Seu foco está definido para hoje. Você pode reorganizar as prioridades quando quiser.')
                : 'Escolha uma prioridade simples para orientar seu dia, no seu ritmo.',
            style: const TextStyle(color: Color(0xFFD7E4E1), height: 1.45),
          ),
          const SizedBox(height: 18),
          if (!hasFocus)
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: onEditFocus,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFE6F0ED),
                  foregroundColor: OrvaColors.primary900,
                  minimumSize: const Size(0, 46),
                ),
                child: const Text('Definir foco'),
              ),
            )
          else
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onToggleCompleted,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFE6F0ED),
                  foregroundColor: OrvaColors.primary900,
                  minimumSize: const Size(0, 46),
                ),
                icon: Icon(completed
                    ? Icons.undo_rounded
                    : Icons.check_circle_outline_rounded),
                label: Text(completed ? 'Reabrir foco' : 'Concluir foco'),
              ),
            ),
        ],
      ),
    );
  }
}

class _ProgressSummary extends StatelessWidget {
  const _ProgressSummary({required this.summary});
  final Map<String, Object?> summary;
  @override
  Widget build(BuildContext context) {
    final done = intValue(summary['checklistCompleted']);
    final total = intValue(summary['checklistTotal']);
    final progress = summary['checklistProgress'] as double?;
    return Row(children: [
      Expanded(child: OrvaSurface(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Icon(Icons.check_circle_outline_rounded, color: OrvaColors.success, size: 22),
        const SizedBox(height: 12),
        Text(progress == null ? '—' : '${(progress * 100).round()}%', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 25)),
        const SizedBox(height: 3),
        Text(progress == null ? 'Sem itens hoje' : '$done de $total concluídos', style: Theme.of(context).textTheme.bodySmall),
        if (progress != null) ...[
          const SizedBox(height: 10),
          ClipRRect(borderRadius: BorderRadius.circular(8), child: LinearProgressIndicator(value: progress, minHeight: 5, backgroundColor: OrvaColors.primary100, color: OrvaColors.primary)),
        ],
      ]))),
      const SizedBox(width: 10),
      Expanded(child: OrvaSurface(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Icon(Icons.flag_outlined, color: OrvaColors.terracotta, size: 22),
        const SizedBox(height: 12),
        Text('${intValue(summary['activeGoals'])}', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 25)),
        const SizedBox(height: 3),
        Text('metas ativas', style: Theme.of(context).textTheme.bodySmall),
      ]))),
    ]);
  }
}

class _HomeChecklistItem extends StatelessWidget {
  const _HomeChecklistItem({required this.item, required this.onChanged});
  final Map<String, Object?> item;
  final ValueChanged<bool> onChanged;
  @override
  Widget build(BuildContext context) {
    final checked = intValue(item['completed']) == 1;
    return CheckboxListTile(
      value: checked,
      onChanged: (value) => onChanged(value ?? false),
      dense: true,
      controlAffinity: ListTileControlAffinity.leading,
      contentPadding: const EdgeInsets.symmetric(horizontal: 10),
      title: Text('${item['title_snapshot'] ?? ''}', style: Theme.of(context).textTheme.bodyLarge?.copyWith(decoration: checked ? TextDecoration.lineThrough : null, color: checked ? OrvaColors.tertiaryText : null)),
      subtitle: Text('${item['checklist_title'] ?? ''}', maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodySmall),
      activeColor: OrvaColors.primary,
    );
  }
}

class _GoalMiniCard extends StatelessWidget {
  const _GoalMiniCard({required this.goal, required this.isDark, required this.onTap});
  final Map<String, Object?> goal;
  final bool isDark;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final progress = doubleValue(goal['progress_value']).clamp(0, 100) / 100;
    return OrvaSurface(onTap: onTap, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(child: Text('${goal['title']}', style: Theme.of(context).textTheme.titleMedium)),
        Text('${(progress * 100).round()}%', style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700, color: OrvaColors.primary)),
      ]),
      if ((goal['category'] as String?)?.isNotEmpty == true) ...[const SizedBox(height: 4), Text('${goal['category']}', style: Theme.of(context).textTheme.bodySmall)],
      const SizedBox(height: 12),
      ClipRRect(borderRadius: BorderRadius.circular(6), child: LinearProgressIndicator(value: progress, minHeight: 5, color: OrvaColors.primary, backgroundColor: isDark ? OrvaColors.darkBorder : OrvaColors.primary100)),
      if (goal['deadline'] != null) ...[const SizedBox(height: 7), Text('Prazo: ${goal['deadline']}', style: Theme.of(context).textTheme.bodySmall)],
    ]));
  }
}

class _RoutineMiniRow extends StatelessWidget {
  const _RoutineMiniRow({required this.block});
  final Map<String, Object?> block;
  @override
  Widget build(BuildContext context) {
    final start = intValue(block['start_minute']);
    final end = intValue(block['end_minute']);
    final now = DateTime.now();
    final current = now.hour * 60 + now.minute;
    final isCurrent = current >= start && current < end;
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SizedBox(width: 62, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(formatClock(start), style: const TextStyle(fontFeatures: [], fontFamily: 'monospace', fontSize: 13, fontWeight: FontWeight.w700)),
        Text(formatClock(end), style: Theme.of(context).textTheme.bodySmall?.copyWith(fontFamily: 'monospace')),
      ])),
      Container(width: 3, height: 42, decoration: BoxDecoration(color: isCurrent ? OrvaColors.terracotta : OrvaColors.information, borderRadius: BorderRadius.circular(4))),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('${block['title']}', style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500)),
        const SizedBox(height: 3),
        Text('${block['category'] ?? 'Sem categoria'} · ${formatMinutes(end - start)} planejados', style: Theme.of(context).textTheme.bodySmall),
      ])),
      if (isCurrent) const Icon(Icons.circle, color: OrvaColors.terracotta, size: 8),
    ]);
  }
}

class _TimeSummaryCard extends StatelessWidget {
  const _TimeSummaryCard({required this.summary, required this.isDark});
  final Map<String, Object?> summary;
  final bool isDark;
  @override
  Widget build(BuildContext context) {
    final blocks = intValue(summary['routineBlocks']);
    final minutes = intValue(summary['plannedMinutes']);
    if (blocks == 0 || minutes == 0) {
      return const OrvaSurface(child: OrvaEmptyState(icon: Icons.timelapse_outlined, title: 'Sem tempo planejado ainda', message: 'Adicione blocos à rotina para visualizar a distribuição do seu dia.', compact: true));
    }
    return OrvaSurface(child: Row(children: [
      Container(width: 46, height: 46, decoration: BoxDecoration(color: isDark ? const Color(0xFF2B3941) : const Color(0xFFE5EEF4), borderRadius: BorderRadius.circular(14)), child: const Icon(Icons.timelapse_outlined, color: OrvaColors.information)),
      const SizedBox(width: 14),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(formatMinutes(minutes), style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 3),
        Text('Tempo planejado em $blocks ${blocks == 1 ? 'bloco' : 'blocos'} hoje. Isso não representa tempo efetivamente realizado.', style: Theme.of(context).textTheme.bodySmall),
      ])),
    ]));
  }
}


/// Wall-clock planning overview. Does not claim activities were completed.
class _DayAllocationCard extends StatelessWidget {
  const _DayAllocationCard({required this.summary, required this.routine});
  final Map<String, Object?> summary;
  final List<Map<String, Object?>> routine;

  @override
  Widget build(BuildContext context) {
    if (routine.isEmpty) {
      return const OrvaSurface(child: OrvaEmptyState(icon: Icons.donut_large_outlined, title: 'Ainda não há horários planejados', message: 'Adicione blocos à rotina para visualizar a ocupação e as horas não definidas.', compact: true));
    }
    final occupied = intValue(summary['plannedMinutes']);
    final free = 1440 - occupied;
    final raw = summary['plannedCategories'];
    final categories = raw is Map<String, int> ? raw : <String, int>{};
    final scheme = Theme.of(context).colorScheme;
    final colors = [OrvaColors.primary, OrvaColors.information, OrvaColors.terracotta,
      OrvaColors.mustard, OrvaColors.success, const Color(0xFF8B6B9E)];
    return OrvaSurface(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Ocupação das 24 horas', style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: 6),
      Text('Planejamento · horários sobrepostos contados uma única vez.', style: Theme.of(context).textTheme.bodySmall),
      const SizedBox(height: 18),
      Center(child: SizedBox(width: 154, height: 154, child: Stack(alignment: Alignment.center, children: [
        SizedBox.expand(child: CustomPaint(painter: _DailyRingPainter(
          minutes: categories.values.toList(), colors: colors,
          freeMinutes: free, emptyColor: scheme.surfaceContainerHighest,
        ))),
        Column(mainAxisSize: MainAxisSize.min, children: [
          Text('${(occupied / 1440 * 100).round()}%', style: Theme.of(context).textTheme.headlineMedium),
          Text('${formatMinutes(occupied)} planejadas', style: Theme.of(context).textTheme.bodySmall),
        ]),
      ]))),
      const SizedBox(height: 18),
      ...categories.entries.toList().asMap().entries.map((entry) {
        final category = entry.value;
        final related = routine.where((block) =>
          ((block['category'] as String?)?.trim().isNotEmpty == true ? block['category'] : 'Sem categoria') == category.key).toList();
        return ExpansionTile(
          tilePadding: EdgeInsets.zero,
          leading: CircleAvatar(radius: 6, backgroundColor: colors[entry.key % colors.length]),
          title: Text(category.key, style: Theme.of(context).textTheme.bodyLarge),
          trailing: Text(formatMinutes(category.value), style: Theme.of(context).textTheme.titleMedium),
          children: related.map((block) => ListTile(
            dense: true, title: Text('${block['title']}'),
            subtitle: Text('${_homeClock(intValue(block['start_minute']))}–${_homeClock(intValue(block['end_minute']))} · horário planejado'),
          )).toList(),
        );
      }),
      const Divider(height: 20),
      Row(children: [
        Expanded(child: Text('Tempo não definido', style: Theme.of(context).textTheme.bodyLarge)),
        Text(formatMinutes(free), style: Theme.of(context).textTheme.titleMedium),
      ]),
      const SizedBox(height: 5),
      Text('Horas livres não são interpretadas como improdutividade.', style: Theme.of(context).textTheme.bodySmall),
    ]));
  }
}

class _DailyRingPainter extends CustomPainter {
  const _DailyRingPainter({required this.minutes, required this.colors, required this.freeMinutes, required this.emptyColor});
  final List<int> minutes;
  final List<Color> colors;
  final int freeMinutes;
  final Color emptyColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 9;
    final rect = Rect.fromCircle(center: center, radius: radius);
    final paint = Paint()..style = PaintingStyle.stroke..strokeWidth = 16;
    var angle = -math.pi / 2;
    for (var i = 0; i < minutes.length; i++) {
      final sweep = minutes[i] / 1440 * 2 * math.pi;
      paint.color = colors[i % colors.length];
      canvas.drawArc(rect, angle, sweep, false, paint);
      angle += sweep;
    }
    paint.color = emptyColor;
    canvas.drawArc(rect, angle, freeMinutes / 1440 * 2 * math.pi, false, paint);
  }

  @override
  bool shouldRepaint(covariant _DailyRingPainter oldDelegate) =>
      oldDelegate.freeMinutes != freeMinutes ||
      oldDelegate.emptyColor != emptyColor ||
      !listEquals(oldDelegate.minutes, minutes);
}

String _homeClock(int minute) => '${(minute ~/ 60).toString().padLeft(2, '0')}:${(minute % 60).toString().padLeft(2, '0')}';

class _HobbyMiniRow extends StatelessWidget {
  const _HobbyMiniRow({required this.hobby});
  final Map<String, Object?> hobby;
  @override
  Widget build(BuildContext context) {
    final actual = intValue(hobby['actual_minutes']);
    final target = hobby['weekly_target_minutes'] as num?;
    final targetMinutes = target?.toInt();
    final progress = target == null || target == 0 ? null : (actual / target.toDouble()).clamp(0.0, 1.0);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [Expanded(child: Text('${hobby['name']}', style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600))), Text(formatMinutes(actual), style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: OrvaColors.terracotta, fontWeight: FontWeight.w700))]),
      const SizedBox(height: 7),
      if (progress != null && targetMinutes != null) ...[
        ClipRRect(borderRadius: BorderRadius.circular(5), child: LinearProgressIndicator(value: progress, minHeight: 5, color: OrvaColors.terracotta, backgroundColor: OrvaColors.terracottaLight)),
        const SizedBox(height: 4),
        Text('Meta semanal: ${formatMinutes(targetMinutes)}', style: Theme.of(context).textTheme.bodySmall),
      ] else
        Text('Tempo registrado nesta semana', style: Theme.of(context).textTheme.bodySmall),
    ]);
  }
}

class _QuickActionTile extends StatelessWidget {
  const _QuickActionTile({required this.icon, required this.title, required this.subtitle, required this.onTap});
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Container(width: 42, height: 42, decoration: BoxDecoration(color: OrvaColors.primary.withValues(alpha: 0.09), borderRadius: BorderRadius.circular(12)), child: Icon(icon, color: OrvaColors.primary)),
        title: Text(title, style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: onTap,
      );
}

/// Reflexão do dia: frase filosófica determinística, discreta, desativável
/// nas Configurações. Não depende de internet.
class _DailyQuoteCard extends ConsumerWidget {
  const _DailyQuoteCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enabled = ref.watch(quotesEnabledProvider).asData?.value ?? true;
    if (!enabled) return const SizedBox.shrink();
    final quote = quoteOfTheDay(DateTime.now());
    return OrvaSurface(
      color: Theme.of(context).brightness == Brightness.dark ? OrvaColors.darkSubtle : OrvaColors.subtle,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Reflexão do dia', style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 8),
        Text('"${quote.text}"', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontStyle: FontStyle.italic)),
        const SizedBox(height: 6),
        Text('— ${quote.author}', style: Theme.of(context).textTheme.bodySmall),
      ]),
    );
  }
}
