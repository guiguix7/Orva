/// Pure Home command-center calculations.
///
/// The Home screen is a projection over records Orva already owns: calendar
/// entries (planned routine blocks, obligations, meal plans and real
/// executions), checklist occurrences, habits, goals and study sessions. This
/// module only positions and aggregates those facts. It never invents
/// progress, never treats planned time as completed time and never stores a
/// second copy of the agenda.
library;

import 'calendar_layout.dart';

/// Where an entry sits relative to the current local time.
///
/// `past` only means the planned interval has ended. It does **not** mean the
/// activity was completed: completion requires a real execution record.
enum HomeEntryPhase { realized, live, upcoming, past }

final class HomeAgendaItem {
  const HomeAgendaItem({required this.entry, required this.phase});

  final CalendarEntry entry;
  final HomeEntryPhase phase;

  bool get isPlanned => !entry.isExecuted;
}

sealed class HomeTimelineSlot {
  const HomeTimelineSlot({required this.startMinute, required this.endMinute});

  final int startMinute;
  final int endMinute;

  int get minutes => endMinute - startMinute;
}

final class HomeEntrySlot extends HomeTimelineSlot {
  HomeEntrySlot(this.item)
    : super(
        startMinute: item.entry.startMinute,
        endMinute: item.entry.endMinute,
      );

  final HomeAgendaItem item;
}

/// An unplanned window long enough to be worth showing (at least two hours).
final class HomeGapSlot extends HomeTimelineSlot {
  const HomeGapSlot({required super.startMinute, required super.endMinute});
}

/// Aggregated, testable view of one local day.
final class HomeOverview {
  HomeOverview._({
    required this.now,
    required this.nowMinute,
    required this.items,
    required this.timeline,
    required this.liveActivity,
    required this.nextActivity,
    required this.plannedMinutes,
    required this.executedMinutes,
    required this.freeMinutes,
    required this.remainingPlannedMinutes,
    required this.conflictCount,
    required this.plannedBlockCount,
    required this.executionCount,
    required this.pendingObligations,
  });

  factory HomeOverview.build({
    required List<CalendarEntry> entries,
    required DateTime now,
  }) {
    final minute = now.hour * 60 + now.minute;
    final items =
        entries
            .map(
              (entry) =>
                  HomeAgendaItem(entry: entry, phase: _phaseFor(entry, minute)),
            )
            .toList()
          ..sort(_compareItems);

    CalendarEntry? live;
    CalendarEntry? next;
    for (final item in items) {
      if (item.entry.isExecuted) continue;
      if (item.phase == HomeEntryPhase.live && live == null) {
        live = item.entry;
      }
      if (item.entry.startMinute > minute && next == null) {
        next = item.entry;
      }
    }

    final planned = _unionMinutes(entries, 0, 1440);
    final executed = entries
        .where((entry) => entry.isExecuted)
        .fold<int>(0, (sum, entry) => sum + entry.durationMinutes);
    final pendingObligations = items
        .where(
          (item) =>
              item.entry.kind == CalendarEntryKind.obligation &&
              item.entry.status != 'completed' &&
              item.entry.status != 'skipped',
        )
        .map((item) => item.entry)
        .toList();

    return HomeOverview._(
      now: now,
      nowMinute: minute,
      items: List.unmodifiable(items),
      timeline: List.unmodifiable(_buildTimeline(items, minute)),
      liveActivity: live,
      nextActivity: next,
      plannedMinutes: planned,
      executedMinutes: executed,
      freeMinutes: 1440 - planned,
      remainingPlannedMinutes: _unionMinutes(entries, minute, 1440),
      conflictCount: conflictCount(entries),
      plannedBlockCount: entries.where((entry) => !entry.isExecuted).length,
      executionCount: entries.where((entry) => entry.isExecuted).length,
      pendingObligations: List.unmodifiable(pendingObligations),
    );
  }

  final DateTime now;
  final int nowMinute;
  final List<HomeAgendaItem> items;

  /// Planned entries in time order, with long unplanned windows between them.
  final List<HomeTimelineSlot> timeline;

  final CalendarEntry? liveActivity;
  final CalendarEntry? nextActivity;

  /// Union of planned minutes, so overlaps are never counted twice.
  final int plannedMinutes;

  /// Time covered by real execution records only.
  final int executedMinutes;

  final int freeMinutes;
  final int remainingPlannedMinutes;
  final int conflictCount;
  final int plannedBlockCount;
  final int executionCount;
  final List<CalendarEntry> pendingObligations;

  bool get hasEntries => items.isNotEmpty;
  bool get hasPlan => plannedBlockCount > 0;

  /// Executed time divided by planned time. Null when nothing was planned, so
  /// the UI never shows a percentage without a denominator.
  double? get executionCoverage {
    if (plannedMinutes == 0) return null;
    return executedMinutes / plannedMinutes;
  }

  bool get isWindingDown => nowMinute >= 18 * 60;

  /// First unplanned quarter-hour from now that can hold a new block.
  int get suggestedBlockStart {
    for (final gap in plannedGaps(
      items.map((item) => item.entry),
      from: nowMinute,
    )) {
      if (gap.minutes >= 30) return _roundToQuarter(gap.startMinute);
    }
    return _roundToQuarter(nowMinute);
  }

  static List<HomeTimelineSlot> _buildTimeline(
    List<HomeAgendaItem> items,
    int nowMinute,
  ) {
    final planned = items.where((item) => item.isPlanned).toList()
      ..sort((a, b) => a.entry.startMinute.compareTo(b.entry.startMinute));
    final slots = <HomeTimelineSlot>[];
    var cursor = 0;
    for (final item in planned) {
      if (item.entry.startMinute - cursor >= 120 &&
          item.entry.endMinute > nowMinute) {
        slots.add(
          HomeGapSlot(startMinute: cursor, endMinute: item.entry.startMinute),
        );
      }
      slots.add(HomeEntrySlot(item));
      if (item.entry.endMinute > cursor) cursor = item.entry.endMinute;
    }
    for (final item in items.where((item) => !item.isPlanned)) {
      slots.add(HomeEntrySlot(item));
    }
    slots.sort((a, b) {
      final byStart = a.startMinute.compareTo(b.startMinute);
      if (byStart != 0) return byStart;
      return a is HomeGapSlot ? -1 : 0;
    });
    return slots;
  }
}

HomeEntryPhase _phaseFor(CalendarEntry entry, int nowMinute) {
  if (entry.isExecuted) return HomeEntryPhase.realized;
  if (entry.startMinute <= nowMinute && nowMinute < entry.endMinute) {
    return HomeEntryPhase.live;
  }
  if (entry.endMinute <= nowMinute) return HomeEntryPhase.past;
  return HomeEntryPhase.upcoming;
}

int _compareItems(HomeAgendaItem a, HomeAgendaItem b) {
  final byStart = a.entry.startMinute.compareTo(b.entry.startMinute);
  if (byStart != 0) return byStart;
  final byKind = (a.entry.isExecuted ? 1 : 0).compareTo(
    b.entry.isExecuted ? 1 : 0,
  );
  if (byKind != 0) return byKind;
  return a.entry.id.compareTo(b.entry.id);
}

/// Union length of planned intervals inside [from, to).
int _unionMinutes(List<CalendarEntry> entries, int from, int to) {
  final intervals = entries.where((entry) => !entry.isExecuted).toList()
    ..sort((a, b) => a.startMinute.compareTo(b.startMinute));
  var total = 0;
  var cursor = from;
  for (final entry in intervals) {
    if (entry.endMinute <= cursor) continue;
    if (entry.startMinute >= to) break;
    final start = entry.startMinute.clamp(from, to).toInt();
    final end = entry.endMinute.clamp(from, to).toInt();
    final effectiveStart = start > cursor ? start : cursor;
    if (end > effectiveStart) {
      total += end - effectiveStart;
      cursor = end;
    }
    if (cursor >= to) break;
  }
  return total;
}

int _roundToQuarter(int minute) {
  final rounded = ((minute + 14) ~/ 15) * 15;
  return rounded.clamp(0, 1425).toInt();
}

// ---------------------------------------------------------------------------
// Checklist, study and habits
// ---------------------------------------------------------------------------

final class ChecklistDigest {
  const ChecklistDigest({required this.completed, required this.total});

  static const empty = ChecklistDigest(completed: 0, total: 0);

  final int completed;
  final int total;

  double? get ratio => total == 0 ? null : completed / total;
  int get remaining => total - completed;
}

final class StudyDigest {
  const StudyDigest({
    required this.minutes,
    required this.sessions,
    required this.reviews,
    required this.studyDays,
  });

  final int minutes;
  final int sessions;
  final int reviews;
  final int studyDays;

  bool get hasEvidence => sessions > 0;
}

final class HabitRecord {
  const HabitRecord({
    required this.id,
    required this.name,
    required this.unit,
    this.target,
    this.activeWeekdays = const <int>{},
  });

  final String id;
  final String name;
  final String unit;
  final double? target;

  /// 1 = Monday ... 7 = Sunday. Empty means every day.
  final Set<int> activeWeekdays;
}

final class HabitDaySignal {
  const HabitDaySignal({
    required this.date,
    required this.eligible,
    required this.logged,
    required this.isToday,
  });

  final DateTime date;
  final bool eligible;
  final bool logged;
  final bool isToday;
}

final class HabitSignal {
  const HabitSignal({
    required this.habit,
    required this.todayQuantity,
    required this.days,
  });

  final HabitRecord habit;
  final double todayQuantity;
  final List<HabitDaySignal> days;

  int get eligibleDays => days.where((day) => day.eligible).length;
  int get loggedDays => days.where((day) => day.eligible && day.logged).length;

  /// Null when there was no eligible opportunity, so no fake percentage.
  double? get consistency =>
      eligibleDays == 0 ? null : loggedDays / eligibleDays;

  bool get isTodayLogged => days.any((day) => day.isToday && day.logged);

  bool get isTodayEligible => days.any((day) => day.isToday && day.eligible);
}

final class HabitReport {
  const HabitReport({
    required this.signals,
    required this.eligibleDays,
    required this.loggedDays,
  });

  static const empty = HabitReport(
    signals: <HabitSignal>[],
    eligibleDays: 0,
    loggedDays: 0,
  );

  final List<HabitSignal> signals;

  /// Sum of eligible opportunities across habits: one per habit per day it is
  /// scheduled for.
  final int eligibleDays;
  final int loggedDays;

  double? get consistency =>
      eligibleDays == 0 ? null : loggedDays / eligibleDays;

  bool get isEmpty => signals.isEmpty;
}

/// Builds per-habit consistency from real habit logs.
///
/// [logsByHabit] maps a habit id to a map of `yyyy-MM-dd` -> quantity. A day
/// counts as logged only when the recorded quantity is greater than zero.
HabitReport buildHabitReport({
  required List<HabitRecord> habits,
  required Map<String, Map<String, double>> logsByHabit,
  required DateTime windowStart,
  required DateTime today,
}) {
  final start = DateTime(windowStart.year, windowStart.month, windowStart.day);
  final end = DateTime(today.year, today.month, today.day);
  final signals = <HabitSignal>[];
  var eligibleTotal = 0;
  var loggedTotal = 0;

  for (final habit in habits) {
    final logs = logsByHabit[habit.id] ?? const <String, double>{};
    final days = <HabitDaySignal>[];
    var eligible = 0;
    var logged = 0;
    for (
      var day = start;
      !day.isAfter(end);
      day = DateTime(day.year, day.month, day.day + 1)
    ) {
      final date = DateTime(day.year, day.month, day.day);
      final isEligible =
          habit.activeWeekdays.isEmpty ||
          habit.activeWeekdays.contains(date.weekday);
      final isLogged = (logs[_dateKey(date)] ?? 0) > 0;
      if (isEligible) {
        eligible++;
        if (isLogged) logged++;
      }
      days.add(
        HabitDaySignal(
          date: date,
          eligible: isEligible,
          logged: isLogged,
          isToday: _isSameDay(date, end),
        ),
      );
    }
    eligibleTotal += eligible;
    loggedTotal += logged;
    signals.add(
      HabitSignal(
        habit: habit,
        todayQuantity: logs[_dateKey(end)] ?? 0,
        days: List.unmodifiable(days),
      ),
    );
  }

  return HabitReport(
    signals: List.unmodifiable(signals),
    eligibleDays: eligibleTotal,
    loggedDays: loggedTotal,
  );
}

String _dateKey(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';

bool _isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;
