import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/database/calendar_repository.dart';
import '../../core/database/orva_repository.dart';
import '../../core/domain/calendar_layout.dart';
import '../../core/domain/orva_calculations.dart';
import '../../core/theme/orva_theme.dart';
import '../../core/theme/orva_tokens.dart';
import '../../core/widgets/orva_widgets.dart';
import '../executions/executions_page.dart';
import '../nutrition/nutrition_page.dart';
import '../obligations/obligations_page.dart';
import '../routine/routine_editor.dart';
import 'calendar_views.dart';

enum CalendarViewMode { day, week, month }

/// Unified calendar over the records Orva already owns: routine blocks
/// (planned), obligations and meals (planned commitments) and executions (real
/// spent time). It is a projection, never a second schedule.
class CalendarPage extends ConsumerStatefulWidget {
  const CalendarPage({
    super.key,
    this.initialDate,
    this.initialMode = CalendarViewMode.day,
    this.initialEntryId,
  });

  final DateTime? initialDate;
  final CalendarViewMode initialMode;

  /// Entry to open as soon as the day view finishes loading, used by Home to
  /// navigate straight from a next-activity card to its details.
  final String? initialEntryId;

  @override
  ConsumerState<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends ConsumerState<CalendarPage> {
  late DateTime _anchor;
  late DateTime _selectedMonthDay;
  CalendarViewMode _mode = CalendarViewMode.day;
  bool _loading = true;
  List<CalendarEntry> _entries = const [];
  Map<String, List<CalendarEntry>> _week = const {};
  Map<String, int> _monthCounts = const {};
  String? _pendingEntryId;

  @override
  void initState() {
    super.initState();
    final now = widget.initialDate ?? DateTime.now();
    _anchor = DateTime(now.year, now.month, now.day);
    _selectedMonthDay = _anchor;
    _mode = widget.initialMode;
    _pendingEntryId = widget.initialEntryId;
    _load();
  }

  DateTime get _editorDate =>
      _mode == CalendarViewMode.month ? _selectedMonthDay : _anchor;

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final repo = ref.read(repositoryProvider);
      List<CalendarEntry> entries = const [];
      Map<String, List<CalendarEntry>> week = const {};
      Map<String, int> counts = const {};
      switch (_mode) {
        case CalendarViewMode.day:
          entries = await repo.loadCalendarEntries(_anchor);
        case CalendarViewMode.week:
          week = await repo.loadCalendarWeek(_anchor);
        case CalendarViewMode.month:
          counts = await repo.loadMonthActivity(_anchor);
          entries = await repo.loadCalendarEntries(_selectedMonthDay);
      }
      if (!mounted) return;
      setState(() {
        _entries = entries;
        _week = week;
        _monthCounts = counts;
        _loading = false;
      });
      _openInitialEntryIfNeeded();
    } catch (error) {
      if (!mounted) return;
      setState(() => _loading = false);
      showOrvaError(context, error);
    }
  }

  void _openInitialEntryIfNeeded() {
    final id = _pendingEntryId;
    if (id == null) return;
    _pendingEntryId = null;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      for (final entry in _entries) {
        if (entry.id == id) {
          _showEntry(entry);
          return;
        }
      }
      showOrvaMessage(context, 'Esta atividade não está mais neste dia.');
    });
  }

  void _shift(int direction) {
    setState(() {
      switch (_mode) {
        case CalendarViewMode.day:
          _anchor = DateTime(
            _anchor.year,
            _anchor.month,
            _anchor.day + direction,
          );
        case CalendarViewMode.week:
          _anchor = DateTime(
            _anchor.year,
            _anchor.month,
            _anchor.day + 7 * direction,
          );
        case CalendarViewMode.month:
          _anchor = addCalendarMonths(_anchor, direction);
          _selectedMonthDay = _anchor;
      }
    });
    _load();
  }

  void _goTo(DateTime date, {CalendarViewMode? mode}) {
    setState(() {
      _anchor = DateTime(date.year, date.month, date.day);
      _selectedMonthDay = _anchor;
      if (mode != null) _mode = mode;
    });
    _load();
  }

  Future<void> _openEditor({
    Map<String, Object?>? block,
    bool duplicate = false,
    int? startMinute,
  }) async {
    await showRoutineEditor(
      context,
      ref,
      block: block,
      duplicate: duplicate,
      initialDate: _editorDate,
      initialStartMinute: startMinute,
      initialBlockKind: 'date',
    );
    await _load();
  }

  Future<void> _editEntry(CalendarEntry entry) async {
    final sourceId = entry.sourceId;
    if (sourceId == null) return;
    try {
      final raw = await ref.read(repositoryProvider).findRoutineBlock(sourceId);
      if (!mounted) return;
      if (raw == null) {
        showOrvaMessage(context, 'Este bloco não existe mais.');
        await _load();
        return;
      }
      await _openEditor(block: raw);
    } catch (error) {
      if (mounted) showOrvaError(context, error);
    }
  }

  Future<void> _deleteEntry(CalendarEntry entry) async {
    final sourceId = entry.sourceId;
    if (sourceId == null) return;
    final confirmed = await confirmAction(
      context,
      title: 'Excluir bloco?',
      message: '“${entry.title}” será removido do planejamento.',
      actionLabel: 'Excluir',
      destructive: true,
    );
    if (!confirmed) return;
    try {
      await ref.read(repositoryProvider).deleteRoutineBlock(sourceId);
      await _load();
    } catch (error) {
      if (mounted) showOrvaError(context, error);
    }
  }

  Future<void> _openSource(CalendarEntry entry) async {
    final page = switch (entry.kind) {
      CalendarEntryKind.obligation => ObligationsPage(initialDate: _anchor),
      CalendarEntryKind.mealPlan => NutritionPage(initialDate: _anchor),
      CalendarEntryKind.execution => const ExecutionsPage(),
      CalendarEntryKind.plannedBlock => null,
    };
    if (page == null) return;
    await Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => page));
    await _load();
  }

  Future<void> _showEntry(CalendarEntry entry) async {
    final color = OrvaCategoryPalette.of(context, entry.category);
    final kindLabel = switch (entry.kind) {
      CalendarEntryKind.plannedBlock => 'Planejado',
      CalendarEntryKind.obligation => 'Obrigação recorrente',
      CalendarEntryKind.mealPlan => 'Refeição planejada',
      CalendarEntryKind.execution => 'Realizado',
    };
    final status = switch (entry.status) {
      'completed' => 'Concluído',
      'skipped' => 'Ignorado neste dia',
      'planned' => 'Ainda planejado',
      _ => null,
    };
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheet) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '$kindLabel · ${entry.category}',
                    style: Theme.of(sheet).textTheme.bodySmall,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(entry.title, style: Theme.of(sheet).textTheme.titleLarge),
              const SizedBox(height: 6),
              Text(
                '${formatClock(entry.startMinute)} – ${formatClock(entry.endMinute)} · ${formatMinutes(entry.durationMinutes)}',
                style: orvaMonoStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              if (status != null) ...[
                const SizedBox(height: 4),
                Text(
                  'Estado: $status',
                  style: Theme.of(sheet).textTheme.bodySmall,
                ),
              ],
              const SizedBox(height: 18),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (entry.isEditable)
                    FilledButton.icon(
                      onPressed: () => Navigator.pop(sheet, 'edit'),
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      label: const Text('Editar'),
                    ),
                  if (entry.isEditable)
                    OutlinedButton.icon(
                      onPressed: () => Navigator.pop(sheet, 'duplicate'),
                      icon: const Icon(Icons.copy_all_outlined, size: 18),
                      label: const Text('Duplicar'),
                    ),
                  if (!entry.isEditable)
                    OutlinedButton.icon(
                      onPressed: () => Navigator.pop(sheet, 'open'),
                      icon: const Icon(Icons.open_in_new_rounded, size: 18),
                      label: Text(
                        entry.kind == CalendarEntryKind.execution
                            ? 'Ver execuções'
                            : 'Abrir origem',
                      ),
                    ),
                  if (entry.isEditable)
                    TextButton(
                      onPressed: () => Navigator.pop(sheet, 'delete'),
                      style: TextButton.styleFrom(
                        foregroundColor: OrvaColors.error,
                      ),
                      child: const Text('Excluir'),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (!mounted || action == null) return;
    switch (action) {
      case 'edit':
        await _editEntry(entry);
      case 'duplicate':
        final raw = entry.sourceId == null
            ? null
            : await ref
                  .read(repositoryProvider)
                  .findRoutineBlock(entry.sourceId!);
        if (!mounted) return;
        await _openEditor(block: raw, duplicate: true);
      case 'delete':
        await _deleteEntry(entry);
      case 'open':
        await _openSource(entry);
    }
  }

  String _periodTitle() {
    final locale = 'pt_BR';
    switch (_mode) {
      case CalendarViewMode.day:
        return _capitalize(
          DateFormat("EEEE, d 'de' MMMM", locale).format(_anchor),
        );
      case CalendarViewMode.week:
        final days = weekDays(_anchor);
        final start = days.first;
        final end = days.last;
        if (start.month == end.month) {
          return '${start.day} – ${end.day} de ${DateFormat('MMMM', locale).format(end)}';
        }
        return '${DateFormat('d MMM', locale).format(start)} – ${DateFormat('d MMM', locale).format(end)}';
      case CalendarViewMode.month:
        return _capitalize(DateFormat('MMMM', locale).format(_anchor));
    }
  }

  String _periodSubtitle() {
    switch (_mode) {
      case CalendarViewMode.day:
        return DateFormat('yyyy').format(_anchor);
      case CalendarViewMode.week:
        return DateFormat('yyyy').format(_anchor);
      case CalendarViewMode.month:
        return DateFormat('yyyy').format(_anchor);
    }
  }

  @override
  Widget build(BuildContext context) {
    final summary = DaySummary.of(_entries);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Calendário'),
        actions: [
          IconButton(
            tooltip: 'Voltar para hoje',
            onPressed: () => _goTo(DateTime.now()),
            icon: const Icon(Icons.today_outlined),
          ),
          IconButton(
            tooltip: 'Modelos semanais',
            onPressed: () async {
              final applied = await showRoutineTemplatesDialog(context, ref);
              if (applied == true) await _load();
            },
            icon: const Icon(Icons.view_week_outlined),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'calendar-create',
        onPressed: () => _openEditor(startMinute: 9 * 60),
        icon: const Icon(Icons.add),
        label: const Text('Novo bloco'),
      ),
      body: Column(
        children: [
          _buildToolbar(context),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : switch (_mode) {
                    CalendarViewMode.day => _buildDay(context, summary),
                    CalendarViewMode.week => WeekBoard(
                      byDay: _week,
                      days: weekDays(_anchor),
                      selectedDay: _anchor,
                      onSelectDay: (day) => _goTo(day),
                      onOpenDay: (day) =>
                          _goTo(day, mode: CalendarViewMode.day),
                    ),
                    CalendarViewMode.month => _buildMonth(context, summary),
                  },
          ),
        ],
      ),
    );
  }

  Widget _buildToolbar(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final compact = width < 600;
    final navigation = Row(
      children: [
        IconButton(
          tooltip: 'Anterior',
          onPressed: () => _shift(-1),
          icon: const Icon(Icons.chevron_left_rounded),
        ),
        Expanded(
          child: Column(
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  _periodTitle(),
                  maxLines: 1,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                _periodSubtitle(),
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: OrvaColors.tertiaryText),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Próximo',
          onPressed: () => _shift(1),
          icon: const Icon(Icons.chevron_right_rounded),
        ),
      ],
    );
    final selector = SegmentedButton<CalendarViewMode>(
      showSelectedIcon: false,
      style: ButtonStyle(
        visualDensity: VisualDensity.compact,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      segments: const [
        ButtonSegment(value: CalendarViewMode.day, label: Text('Dia')),
        ButtonSegment(value: CalendarViewMode.week, label: Text('Semana')),
        ButtonSegment(value: CalendarViewMode.month, label: Text('Mês')),
      ],
      selected: {_mode},
      onSelectionChanged: (value) => _goTo(_anchor, mode: value.first),
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        OrvaSpace.md,
        0,
        OrvaSpace.md,
        OrvaSpace.xs,
      ),
      child: Column(
        children: [
          if (compact) ...[
            navigation,
            const SizedBox(height: OrvaSpace.xs),
            Row(
              children: [
                Expanded(child: selector),
                const SizedBox(width: OrvaSpace.xs),
                TextButton(
                  onPressed: () => _goTo(DateTime.now()),
                  child: const Text('Hoje'),
                ),
              ],
            ),
          ] else
            Row(
              children: [
                Flexible(flex: 2, child: navigation),
                const SizedBox(width: OrvaSpace.md),
                selector,
                const SizedBox(width: OrvaSpace.xs),
                TextButton(
                  onPressed: () => _goTo(DateTime.now()),
                  child: const Text('Hoje'),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildDay(BuildContext context, DaySummary summary) {
    final isToday = isSameLocalDay(_anchor, DateTime.now());
    return Column(
      children: [
        _DaySummaryStrip(summary: summary, isToday: isToday),
        const SizedBox(height: OrvaSpace.xs),
        Expanded(
          child: Stack(
            children: [
              DayTimeline(
                date: _anchor,
                entries: _entries,
                onEntryTap: _showEntry,
                onCreateAt: (minute) => _openEditor(startMinute: minute),
              ),
              if (_entries.isEmpty)
                Positioned(
                  left: OrvaSpace.lg,
                  right: OrvaSpace.lg,
                  bottom: 96,
                  child: IgnorePointer(
                    child: Center(
                      child: Text(
                        'Nada planejado. Toque em um horário ou em “Novo bloco”.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodySmall
                            ?.copyWith(color: OrvaColors.tertiaryText),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMonth(BuildContext context, DaySummary summary) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(OrvaSpace.md, 0, OrvaSpace.md, 124),
      children: [
        OrvaSurface(
          padding: const EdgeInsets.fromLTRB(8, 12, 8, 8),
          child: MonthGrid(
            month: _anchor,
            selectedDay: _selectedMonthDay,
            counts: _monthCounts,
            onSelect: (day) {
              setState(() => _selectedMonthDay = day);
              _load();
            },
          ),
        ),
        const SizedBox(height: OrvaSpace.md),
        _SelectedDayPreview(
          date: _selectedMonthDay,
          entries: _entries,
          summary: summary,
          onOpenDay: () => _goTo(_selectedMonthDay, mode: CalendarViewMode.day),
        ),
      ],
    );
  }
}

class _DaySummaryStrip extends StatelessWidget {
  const _DaySummaryStrip({required this.summary, required this.isToday});

  final DaySummary summary;
  final bool isToday;

  @override
  Widget build(BuildContext context) {
    final items = <({String label, String value, Color color})>[
      (
        label: 'Planejado',
        value: formatMinutes(summary.planned),
        color: OrvaColors.primary,
      ),
      (
        label: 'Livre',
        value: formatMinutes(summary.free),
        color: OrvaColors.tertiaryText,
      ),
      if (summary.executed > 0)
        (
          label: 'Executado',
          value: formatMinutes(summary.executed),
          color: OrvaColors.information,
        ),
      if (summary.conflicts > 0)
        (
          label: 'Conflitos',
          value: '${summary.conflicts}',
          color: OrvaColors.mustard,
        ),
    ];
    return SizedBox(
      height: 54,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: OrvaSpace.md),
        child: Row(
          children: [
            for (final item in items)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(right: OrvaSpace.xs),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(OrvaRadius.sm),
                      border: Border.all(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? OrvaColors.darkBorder
                            : OrvaColors.border,
                      ),
                      color: Theme.of(context).brightness == Brightness.dark
                          ? OrvaColors.darkSurface
                          : OrvaColors.surface,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            item.label.toUpperCase(),
                            maxLines: 1,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  fontSize: 9.5,
                                  letterSpacing: 0.4,
                                  fontWeight: FontWeight.w700,
                                  color: OrvaColors.tertiaryText,
                                ),
                          ),
                        ),
                        const SizedBox(height: 2),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            item.value,
                            maxLines: 1,
                            style: orvaMonoStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: item.color,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SelectedDayPreview extends StatelessWidget {
  const _SelectedDayPreview({
    required this.date,
    required this.entries,
    required this.summary,
    required this.onOpenDay,
  });

  final DateTime date;
  final List<CalendarEntry> entries;
  final DaySummary summary;
  final VoidCallback onOpenDay;

  @override
  Widget build(BuildContext context) {
    return OrvaSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  _capitalize(
                    DateFormat("EEEE, d 'de' MMMM", 'pt_BR').format(date),
                  ),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              TextButton(onPressed: onOpenDay, child: const Text('Abrir dia')),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            '${formatMinutes(summary.planned)} planejados · ${formatMinutes(summary.free)} livres',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: OrvaSpace.sm),
          if (entries.isEmpty)
            Text(
              'Nenhuma atividade neste dia.',
              style: Theme.of(context).textTheme.bodySmall,
            )
          else
            for (final entry in entries.take(4))
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Container(
                      width: 3,
                      height: 30,
                      decoration: BoxDecoration(
                        color: OrvaCategoryPalette.of(context, entry.category),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 10),
                    SizedBox(
                      width: 82,
                      child: Text(
                        formatClock(entry.startMinute),
                        style: orvaMonoStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        entry.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                    if (entry.isExecuted)
                      Text(
                        'realizado',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: OrvaColors.information,
                          fontSize: 10,
                        ),
                      ),
                  ],
                ),
              ),
          if (entries.length > 4)
            Text(
              '+${entries.length - 4} atividades',
              style: Theme.of(context).textTheme.bodySmall,
            ),
        ],
      ),
    );
  }
}

/// Daily timeline with an hour axis, positioned blocks, overlap columns and a
/// live "now" line. Tapping an empty slot creates a block at that time.
class DayTimeline extends StatefulWidget {
  const DayTimeline({
    super.key,
    required this.date,
    required this.entries,
    required this.onEntryTap,
    required this.onCreateAt,
  });

  final DateTime date;
  final List<CalendarEntry> entries;
  final ValueChanged<CalendarEntry> onEntryTap;
  final ValueChanged<int> onCreateAt;

  @override
  State<DayTimeline> createState() => _DayTimelineState();
}

class _DayTimelineState extends State<DayTimeline> {
  static const double _hourHeight = 64;
  static const double _gutterWidth = 52;
  final ScrollController _controller = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollIntoView());
  }

  @override
  void didUpdateWidget(covariant DayTimeline oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!isSameLocalDay(oldWidget.date, widget.date)) _scrollIntoView();
  }

  void _scrollIntoView() {
    if (!_controller.hasClients) return;
    final now = DateTime.now();
    final minute = isSameLocalDay(widget.date, now)
        ? now.hour * 60 + now.minute - 120
        : 7 * 60;
    final target = minute / 60 * _hourHeight;
    _controller.jumpTo(
      target.clamp(0, _controller.position.maxScrollExtent).toDouble(),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final line = isDark ? OrvaColors.darkBorder : OrvaColors.border;
    final now = DateTime.now();
    final isToday = isSameLocalDay(widget.date, now);
    final positioned = layoutDayLanes(widget.entries);
    return SingleChildScrollView(
      controller: _controller,
      padding: const EdgeInsets.only(top: 10, bottom: OrvaSpace.xl),
      child: SizedBox(
        height: 24 * _hourHeight,
        child: Row(
          children: [
            SizedBox(
              width: _gutterWidth,
              child: Stack(
                children: [
                  for (var hour = 1; hour < 24; hour++)
                    Positioned(
                      top: hour * _hourHeight - 7,
                      right: 10,
                      child: Text(
                        '${hour.toString().padLeft(2, '0')}:00',
                        style: orvaMonoStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          color: OrvaColors.tertiaryText,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final width = constraints.maxWidth;
                  return Stack(
                    children: [
                      Positioned.fill(
                        child: GestureDetector(
                          behavior: HitTestBehavior.translucent,
                          onTapDown: (details) {
                            final minute =
                                ((details.localPosition.dy / _hourHeight) *
                                        60 /
                                        15)
                                    .round() *
                                15;
                            widget.onCreateAt(minute.clamp(0, 1425));
                          },
                        ),
                      ),
                      for (var hour = 0; hour <= 24; hour++)
                        Positioned(
                          top: hour * _hourHeight,
                          left: 0,
                          right: 0,
                          child: Container(
                            height: 1,
                            color: line.withValues(alpha: 0.85),
                          ),
                        ),
                      for (var hour = 0; hour < 24; hour++)
                        Positioned(
                          top: hour * _hourHeight + _hourHeight / 2,
                          left: 0,
                          right: 0,
                          child: Container(
                            height: 1,
                            color: line.withValues(alpha: 0.35),
                          ),
                        ),
                      for (final item in positioned)
                        _positionedBlock(context, item, width),
                      if (isToday)
                        Positioned(
                          top:
                              (now.hour * 60 + now.minute) / 60 * _hourHeight -
                              1,
                          left: 0,
                          right: 0,
                          child: IgnorePointer(
                            child: Row(
                              children: [
                                Container(
                                  width: 7,
                                  height: 7,
                                  decoration: const BoxDecoration(
                                    color: OrvaColors.terracotta,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                Expanded(
                                  child: Container(
                                    height: 1.6,
                                    color: OrvaColors.terracotta,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _positionedBlock(
    BuildContext context,
    PositionedEntry item,
    double width,
  ) {
    final entry = item.entry;
    final color = OrvaCategoryPalette.of(context, entry.category);
    final height = math.max(entry.durationMinutes / 60 * _hourHeight - 3, 22.0);
    return Positioned(
      top: entry.startMinute / 60 * _hourHeight + 1,
      height: height,
      left: width * item.lane / item.laneCount + 1,
      width: width / item.laneCount - 3,
      child: Semantics(
        button: true,
        label:
            '${entry.title}, ${formatClock(entry.startMinute)} às ${formatClock(entry.endMinute)}${entry.isExecuted ? ', realizado' : ', planejado'}',
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(OrvaRadius.xs),
            onTap: () => widget.onEntryTap(entry),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
              decoration: BoxDecoration(
                color: entry.isExecuted
                    ? Colors.transparent
                    : OrvaCategoryPalette.soft(context, color),
                borderRadius: BorderRadius.circular(OrvaRadius.xs),
                border: Border(
                  left: BorderSide(
                    color: color,
                    width: entry.isExecuted ? 1.5 : 3,
                  ),
                  top: entry.isExecuted
                      ? BorderSide(color: color.withValues(alpha: 0.5))
                      : BorderSide.none,
                  right: entry.isExecuted
                      ? BorderSide(color: color.withValues(alpha: 0.5))
                      : BorderSide.none,
                  bottom: entry.isExecuted
                      ? BorderSide(color: color.withValues(alpha: 0.5))
                      : BorderSide.none,
                ),
              ),
              child: ClipRect(
                child: height < 34
                    ? Text(
                        entry.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          height: 1.2,
                        ),
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            entry.title,
                            maxLines: height > 60 ? 2 : 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              height: 1.2,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            entry.isExecuted
                                ? 'realizado · ${formatMinutes(entry.durationMinutes)}'
                                : '${formatClock(entry.startMinute)} – ${formatClock(entry.endMinute)}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontFamily: 'JetBrainsMono',
                              fontFamilyFallback: const [
                                'Roboto Mono',
                                'monospace',
                              ],
                              fontSize: 10,
                              height: 1.2,
                              color: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.color,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

String _capitalize(String value) =>
    value.isEmpty ? value : '${value[0].toUpperCase()}${value.substring(1)}';
