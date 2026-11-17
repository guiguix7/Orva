import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/database/calendar_repository.dart';
import '../../core/database/habits_repository.dart';
import '../../core/database/orva_repository.dart';
import '../../core/database/study_repository.dart';
import '../../core/domain/calendar_layout.dart';
import '../../core/domain/home_overview.dart';
import '../../core/domain/orva_calculations.dart';
import '../../core/logging/orva_diagnostics.dart';
import '../../core/theme/orva_theme.dart';
import '../../core/theme/orva_tokens.dart';
import '../../core/widgets/orva_widgets.dart';
import '../calendar/calendar_page.dart';
import '../checklists/checklists_page.dart';
import '../executions/executions_page.dart';
import '../goals/goals_page.dart';
import '../habits/habits_page.dart';
import '../obligations/obligations_page.dart';
import '../quotes/quotes_data.dart';
import '../routine/routine_editor.dart';
import '../studies/study_page.dart';
import 'home_widgets.dart';

/// Home = command center.
///
/// It answers, in order: what is happening today, what comes next, what is
/// still open, how much time was planned versus actually executed and which
/// evidence-backed progress exists. Everything is a projection over records
/// owned by their own repositories; the Home never stores its own agenda.
class HomePage extends ConsumerStatefulWidget {
  const HomePage({
    super.key,
    required this.onNavigate,
    required this.refreshSignal,
  });

  final ValueChanged<int> onNavigate;
  final int refreshSignal;

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  bool _loading = true;
  DateTime _now = DateTime.now();
  Timer? _clock;
  String? _userName;
  HomeOverview? _overview;
  ChecklistDigest _checklist = ChecklistDigest.empty;
  List<Map<String, Object?>> _items = const [];
  List<Map<String, Object?>> _goals = const [];
  List<CalendarEntry> _entries = const [];
  List<HabitRecord> _habitRecords = const [];
  HabitReport _habits = HabitReport.empty;
  StudyDigest _study = const StudyDigest(
    minutes: 0,
    sessions: 0,
    reviews: 0,
    studyDays: 0,
  );
  String? _error;

  @override
  void initState() {
    super.initState();
    _clock = Timer.periodic(const Duration(minutes: 1), (_) {
      if (!mounted) return;
      final now = DateTime.now();
      final dayChanged = !isSameLocalDay(now, _now);
      setState(() {
        _now = now;
        if (!dayChanged && _overview != null) {
          _overview = HomeOverview.build(entries: _entries, now: now);
        }
      });
      if (dayChanged) _load();
    });
    _load();
  }

  @override
  void dispose() {
    _clock?.cancel();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant HomePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshSignal != widget.refreshSignal) _load();
  }

  Future<void> _openPage(Widget page) async {
    await Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => page));
    if (mounted) await _load();
  }

  Future<void> _load() async {
    try {
      final repo = ref.read(repositoryProvider);
      final now = DateTime.now();
      final day = DateTime(now.year, now.month, now.day);
      final weekStart = DateTime(
        day.year,
        day.month,
        day.day - (day.weekday - 1),
      );
      // Rolling window: every habit is judged over the same seven local days,
      // so a Monday does not produce a one-day "100%" consistency figure.
      final habitWindowStart = DateTime(day.year, day.month, day.day - 6);

      final habitRows = await repo.getHabits();
      final habitRecords = <HabitRecord>[];
      final logsByHabit = <String, Map<String, double>>{};
      for (final row in habitRows) {
        final id = row['id'] as String;
        habitRecords.add(
          HabitRecord(
            id: id,
            name: (row['name'] as String?)?.trim().isNotEmpty == true
                ? row['name'] as String
                : 'Hábito',
            unit: (row['unit'] as String?)?.trim().isNotEmpty == true
                ? row['unit'] as String
                : 'vezes',
            target: (row['target_value'] as num?)?.toDouble(),
            activeWeekdays: _parseActiveDays(row['active_days_json']),
          ),
        );
        final logRows = await repo.getHabitLogs(
          id,
          from: habitWindowStart,
          to: day,
        );
        logsByHabit[id] = {
          for (final log in logRows)
            if (log['log_date'] is String)
              log['log_date'] as String:
                  (log['quantity'] as num?)?.toDouble() ?? 0,
        };
      }

      final values = await Future.wait<Object?>([
        repo.getSetting('user_name'),
        repo.loadCalendarEntries(day),
        repo.getTodayOccurrenceItems(day),
        repo.getGoals(status: 'active'),
        repo.getStudySummary(from: weekStart, to: day),
      ]);
      final entries = (values[1] as List<CalendarEntry>).toList();
      final items = values[2] as List<Map<String, Object?>>;
      final completed = items
          .where((item) => intValue(item['completed']) == 1)
          .length;
      final studyRow = values[4] as Map<String, Object?>;
      final report = buildHabitReport(
        habits: habitRecords,
        logsByHabit: logsByHabit,
        windowStart: habitWindowStart,
        today: day,
      );

      if (!mounted) return;
      setState(() {
        _userName = (values[0] as String?)?.trim();
        _entries = entries;
        _overview = HomeOverview.build(entries: entries, now: now);
        _checklist = ChecklistDigest(completed: completed, total: items.length);
        _items = items;
        _goals = (values[3] as List<Map<String, Object?>>).take(3).toList();
        _habitRecords = habitRecords;
        _habits = report;
        _study = StudyDigest(
          minutes: intValue(studyRow['minutes']),
          sessions: intValue(studyRow['sessions']),
          reviews: intValue(studyRow['reviews']),
          studyDays: intValue(studyRow['studyDays']),
        );
        _loading = false;
        _error = null;
      });
    } catch (error, stackTrace) {
      OrvaDiagnostics.instance.recordException(
        error,
        stackTrace,
        category: 'ui-operation',
        module: 'home',
      );
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Não foi possível carregar o seu dia agora. Seus registros continuam salvos neste aparelho.';
      });
    }
  }

  Set<int> _parseActiveDays(Object? raw) {
    if (raw is! String || raw.trim().isEmpty) return const <int>{};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded
            .whereType<num>()
            .map((value) => value.toInt())
            .where((value) => value >= 1 && value <= 7)
            .toSet();
      }
    } on FormatException {
      // A malformed preference must not break the Home; fall back to every day.
    }
    return const <int>{};
  }

  // -------------------------------------------------------------------------
  // Actions
  // -------------------------------------------------------------------------

  Future<void> _openCalendar({String? entryId}) =>
      _openPage(CalendarPage(initialDate: _now, initialEntryId: entryId));

  Future<void> _openEntry(HomeAgendaItem item) =>
      _openCalendar(entryId: item.entry.id);

  Future<void> _planDay() async {
    try {
      await showRoutineEditor(
        context,
        ref,
        initialDate: _now,
        initialStartMinute: _overview?.suggestedBlockStart ?? 9 * 60,
        initialBlockKind: 'date',
      );
      await _load();
    } catch (error) {
      if (mounted) showOrvaError(context, error);
    }
  }

  Future<void> _addTask() async {
    try {
      await showAddTodayTaskDialog(context, ref);
      await _load();
    } catch (error) {
      if (mounted) showOrvaError(context, error);
    }
  }

  Future<void> _toggleChecklistItem(Map<String, Object?> item) async {
    final id = item['id'] as String?;
    if (id == null) return;
    try {
      await ref
          .read(repositoryProvider)
          .setOccurrenceItemCompleted(id, intValue(item['completed']) != 1);
      await _load();
    } catch (error) {
      if (mounted) showOrvaError(context, error);
    }
  }

  Future<void> _handleQuickAction(HomeQuickAction action) async {
    switch (action) {
      case HomeQuickAction.block:
        await _planDay();
      case HomeQuickAction.task:
        await _addTask();
      case HomeQuickAction.execution:
        try {
          await showExecutionEditor(context, ref);
          await _load();
        } catch (error) {
          if (mounted) showOrvaError(context, error);
        }
      case HomeQuickAction.habit:
        await _logHabit();
      case HomeQuickAction.calendar:
        await _openCalendar();
    }
  }

  Future<void> _logHabit() async {
    if (_habitRecords.isEmpty) {
      await _openPage(const HabitsPage());
      return;
    }
    final selected = await showModalBottomSheet<HabitRecord>(
      context: context,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Registrar hábito',
                style: Theme.of(sheetContext).textTheme.titleLarge,
              ),
              const SizedBox(height: 4),
              Text(
                'O valor substitui o registro de hoje.',
                style: Theme.of(sheetContext).textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              for (final habit in _habitRecords)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(
                    Icons.repeat_rounded,
                    color: OrvaColors.terracotta,
                  ),
                  title: Text(habit.name),
                  subtitle: Text(_todayHabitLabel(habit)),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => Navigator.pop(sheetContext, habit),
                ),
            ],
          ),
        ),
      ),
    );
    if (selected == null || !mounted) return;

    final signalIndex = _habits.signals.indexWhere(
      (signal) => signal.habit.id == selected.id,
    );
    final current = signalIndex == -1
        ? 0.0
        : _habits.signals[signalIndex].todayQuantity;
    final raw = await showDialog<String>(
      context: context,
      builder: (_) => _HabitQuantityDialog(
        habitName: selected.name,
        unit: selected.unit,
        initialValue: _formatQuantity(
          current > 0 ? current : (selected.target ?? 1),
        ),
      ),
    );
    if (raw == null || !mounted) return;

    final quantity = double.tryParse(raw.trim().replaceAll(',', '.'));
    if (quantity == null || !quantity.isFinite || quantity < 0) {
      showOrvaMessage(context, 'Informe uma quantidade válida.');
      return;
    }
    try {
      await ref
          .read(repositoryProvider)
          .logHabit(habitId: selected.id, date: _now, quantity: quantity);
      await _load();
    } catch (error) {
      if (mounted) showOrvaError(context, error);
    }
  }

  String _todayHabitLabel(HabitRecord habit) {
    final index = _habits.signals.indexWhere(
      (signal) => signal.habit.id == habit.id,
    );
    if (index == -1) return 'Sem registro nesta semana';
    final signal = _habits.signals[index];
    final value = _formatQuantity(signal.todayQuantity);
    if (!signal.isTodayEligible) return 'Fora dos dias ativos hoje';
    if (signal.todayQuantity <= 0) return 'Ainda sem registro hoje';
    return '$value ${habit.unit} hoje';
  }

  // -------------------------------------------------------------------------
  // Build
  // -------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final nameState = ref.watch(userNameProvider);
    final currentName = nameState.hasValue ? nameState.value : _userName;
    final quotesEnabled =
        ref.watch(quotesEnabledProvider).asData?.value ?? true;
    final overview = _overview;

    Widget body;
    if (_loading && overview == null) {
      body = const _HomeScaffold(child: HomeSkeleton());
    } else if (_error != null) {
      body = _HomeScaffold(
        child: OrvaEmptyState(
          icon: Icons.cloud_off_rounded,
          title: 'Não foi possível carregar',
          message: _error!,
          actionLabel: 'Tentar novamente',
          onAction: _load,
        ),
      );
    } else if (overview == null) {
      body = const _HomeScaffold(child: HomeSkeleton());
    } else {
      body = LayoutBuilder(
        builder: (context, constraints) {
          final hasSecondary =
              _items.isNotEmpty ||
              overview.pendingObligations.isNotEmpty ||
              !_habits.isEmpty ||
              _goals.isNotEmpty ||
              _study.hasEvidence;
          final wide = constraints.maxWidth >= 980 && hasSecondary;
          final horizontal = constraints.maxWidth < 420 ? 18.0 : 24.0;
          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: wide ? 1180 : 760),
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      horizontal,
                      10,
                      horizontal,
                      96,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        HomeTopBar(
                          onOpenCalendar: _openCalendar,
                          onOpenSettings: () => widget.onNavigate(3),
                        ),
                        const SizedBox(height: OrvaSpace.lg),
                        HomeGreeting(
                          greeting: greetingForHour(_now.hour),
                          name: currentName,
                          dateLabel: DateFormat(
                            "EEEE, d 'de' MMMM",
                            'pt_BR',
                          ).format(_now),
                          isWeekend: _now.weekday >= 6,
                        ),
                        const SizedBox(height: OrvaSpace.lg),
                        if (wide)
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                flex: 7,
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: _primaryColumn(overview),
                                ),
                              ),
                              const SizedBox(width: OrvaSpace.lg),
                              Expanded(
                                flex: 5,
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: _secondaryColumn(
                                    overview,
                                    quotesEnabled: quotesEnabled,
                                  ),
                                ),
                              ),
                            ],
                          )
                        else
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              ..._primaryColumn(overview),
                              const SizedBox(height: OrvaSpace.lg),
                              ..._secondaryColumn(
                                overview,
                                quotesEnabled: quotesEnabled,
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      );
    }

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(onRefresh: _load, child: body),
      ),
    );
  }

  List<Widget> _primaryColumn(HomeOverview overview) {
    return [
      HomeHero(
        overview: overview,
        checklist: _checklist,
        onPlanDay: _planDay,
        onAddTask: _addTask,
        onOpenCalendar: _openCalendar,
      ),
      const SizedBox(height: 12),
      HomeQuickActionBar(onAction: _handleQuickAction),
      if (overview.hasEntries) ...[
        const SizedBox(height: OrvaSpace.lg),
        NextActivityCard(
          item: _highlightedItem(overview),
          nowMinute: overview.nowMinute,
          onOpen: _openEntry,
        ),
        const SizedBox(height: OrvaSpace.lg),
        DayTimelinePreview(
          slots: overview.timeline,
          nowMinute: overview.nowMinute,
          onOpenCalendar: _openCalendar,
          onOpenEntry: _openEntry,
          onPlan: _planDay,
        ),
      ],
    ];
  }

  List<Widget> _secondaryColumn(
    HomeOverview overview, {
    required bool quotesEnabled,
  }) {
    final sections = <Widget>[];

    final hasPriorities =
        _items.isNotEmpty || overview.pendingObligations.isNotEmpty;
    if (hasPriorities) {
      sections.add(
        PrioritiesCard(
          items: _items,
          obligations: overview.pendingObligations,
          onToggleItem: _toggleChecklistItem,
          onOpenChecklists: () => widget.onNavigate(1),
          onOpenObligations: () =>
              _openPage(ObligationsPage(initialDate: _now)),
        ),
      );
    }

    if (!_habits.isEmpty) {
      if (sections.isNotEmpty) {
        sections.add(const SizedBox(height: OrvaSpace.lg));
      }
      sections.add(
        HabitConsistencyCard(
          report: _habits,
          onOpen: () => _openPage(const HabitsPage()),
        ),
      );
    }

    if (_goals.isNotEmpty) {
      if (sections.isNotEmpty) {
        sections.add(const SizedBox(height: OrvaSpace.lg));
      }
      sections.add(
        GoalsCard(
          goals: _goals,
          onOpen: () => widget.onNavigate(2),
          onCreate: () async {
            await showGoalEditor(context, ref);
            await _load();
          },
        ),
      );
    }

    if (_study.hasEvidence) {
      if (sections.isNotEmpty) {
        sections.add(const SizedBox(height: OrvaSpace.lg));
      }
      sections.add(
        StudyEvidenceCard(
          study: _study,
          onOpen: () => _openPage(const StudyPage()),
        ),
      );
    }

    if (sections.isEmpty && !overview.hasEntries) {
      sections.add(
        const HomeQuietState(
          icon: Icons.insights_outlined,
          message: 'Consistência, metas e estudo aparecem aqui assim que você registrar os primeiros dados.',
        ),
      );
    }

    if (quotesEnabled) {
      if (sections.isNotEmpty) {
        sections.add(const SizedBox(height: OrvaSpace.lg));
      }
      sections.add(
        HomeReflectionCard(
          quote: quoteOfTheDay(_now).text,
          author: quoteOfTheDay(_now).author,
        ),
      );
    }

    return sections;
  }

  HomeAgendaItem? _highlightedItem(HomeOverview overview) {
    if (overview.liveActivity != null) {
      for (final item in overview.items) {
        if (item.phase == HomeEntryPhase.live && !item.entry.isExecuted) {
          return item;
        }
      }
    }
    if (overview.nextActivity != null) {
      for (final item in overview.items) {
        if (item.entry.id == overview.nextActivity!.id) return item;
      }
    }
    return null;
  }
}

class _HomeScaffold extends StatelessWidget {
  const _HomeScaffold({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(
          constraints.maxWidth < 420 ? 18 : 24,
          10,
          constraints.maxWidth < 420 ? 18 : 24,
          96,
        ),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: child,
            ),
          ),
        ],
      ),
    );
  }
}

String _formatQuantity(double value) {
  if (value == value.roundToDouble()) return value.round().toString();
  return value.toStringAsFixed(1);
}

class _HabitQuantityDialog extends StatefulWidget {
  const _HabitQuantityDialog({
    required this.habitName,
    required this.unit,
    required this.initialValue,
  });

  final String habitName;
  final String unit;
  final String initialValue;

  @override
  State<_HabitQuantityDialog> createState() => _HabitQuantityDialogState();
}

class _HabitQuantityDialogState extends State<_HabitQuantityDialog> {
  late final _controller = TextEditingController(text: widget.initialValue);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text('Registrar ${widget.habitName}'),
    content: TextField(
      controller: _controller,
      autofocus: true,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(labelText: widget.unit),
      onSubmitted: (_) => _submit(),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancelar'),
      ),
      FilledButton(onPressed: _submit, child: const Text('Salvar')),
    ],
  );

  void _submit() => Navigator.pop(context, _controller.text);
}
