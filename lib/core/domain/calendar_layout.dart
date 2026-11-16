/// Pure calendar layout and aggregation for the unified time-blocking view.
///
/// Existing records keep their own domain: routine blocks are planned time,
/// obligations and meal plans are planned commitments, executions are real
/// spent time. This module only positions and aggregates them for display, so
/// no second schedule database and no duplicated activity exists.
library;

enum CalendarEntryKind { plannedBlock, obligation, mealPlan, execution }

final class CalendarEntry {
  CalendarEntry({
    required this.id,
    required this.kind,
    required this.title,
    required this.category,
    required this.startMinute,
    required this.endMinute,
    this.status,
    this.sourceId,
  }) {
    if (startMinute < 0 || startMinute >= 1440) {
      throw ArgumentError.value(
        startMinute,
        'startMinute',
        'Minuto fora do dia.',
      );
    }
    if (endMinute <= startMinute || endMinute > 1440) {
      throw ArgumentError.value(endMinute, 'endMinute', 'Intervalo inválido.');
    }
  }

  final String id;
  final CalendarEntryKind kind;
  final String title;
  final String category;
  final int startMinute;
  final int endMinute;

  /// Domain status when the source has one (planned, completed, skipped).
  final String? status;

  /// Source record identifier inside its own module, when applicable.
  final String? sourceId;

  bool get isExecuted => kind == CalendarEntryKind.execution;

  bool get isEditable => kind == CalendarEntryKind.plannedBlock;

  int get durationMinutes => endMinute - startMinute;
}

/// A calendar entry with its column inside an overlap cluster. `laneCount` is
/// the number of columns needed by the cluster, so overlapping entries are
/// rendered side by side instead of hiding each other.
final class PositionedEntry {
  const PositionedEntry({
    required this.entry,
    required this.lane,
    required this.laneCount,
  });

  final CalendarEntry entry;
  final int lane;
  final int laneCount;
}

int _compareEntries(CalendarEntry a, CalendarEntry b) {
  final byStart = a.startMinute.compareTo(b.startMinute);
  if (byStart != 0) return byStart;
  final byEnd = b.endMinute.compareTo(a.endMinute);
  if (byEnd != 0) return byEnd;
  return a.id.compareTo(b.id);
}

/// Assigns lanes inside each overlap cluster. Entries that do not overlap keep
/// full width; overlapping clusters are split evenly.
List<PositionedEntry> layoutDayLanes(Iterable<CalendarEntry> entries) {
  final sorted = entries.toList()..sort(_compareEntries);
  final result = <PositionedEntry>[];
  var cluster = <CalendarEntry>[];
  var clusterEnd = -1;

  void flush() {
    if (cluster.isEmpty) return;
    final laneEnds = <int>[];
    final laneOf = <String, int>{};
    for (final entry in cluster) {
      var lane = laneEnds.indexWhere((end) => end <= entry.startMinute);
      if (lane == -1) {
        laneEnds.add(entry.endMinute);
        lane = laneEnds.length - 1;
      } else {
        laneEnds[lane] = entry.endMinute;
      }
      laneOf[entry.id] = lane;
    }
    for (final entry in cluster) {
      result.add(
        PositionedEntry(
          entry: entry,
          lane: laneOf[entry.id]!,
          laneCount: laneEnds.length,
        ),
      );
    }
    cluster = <CalendarEntry>[];
    clusterEnd = -1;
  }

  for (final entry in sorted) {
    if (cluster.isNotEmpty && entry.startMinute >= clusterEnd) flush();
    cluster.add(entry);
    if (entry.endMinute > clusterEnd) clusterEnd = entry.endMinute;
  }
  flush();
  return result;
}

final class MinuteGap {
  const MinuteGap(this.startMinute, this.endMinute);

  final int startMinute;
  final int endMinute;

  int get minutes => endMinute - startMinute;
}

/// Union of planned intervals. Executions are deliberately excluded: free time
/// describes what is unplanned, not what was left unused.
List<MinuteGap> plannedGaps(
  Iterable<CalendarEntry> entries, {
  int from = 0,
  int to = 1440,
}) {
  final intervals = entries.where((entry) => !entry.isExecuted).toList()
    ..sort(_compareEntries);
  final gaps = <MinuteGap>[];
  var cursor = from;
  for (final entry in intervals) {
    final start = entry.startMinute.clamp(from, to).toInt();
    final end = entry.endMinute.clamp(from, to).toInt();
    if (end <= cursor) continue;
    if (start > cursor) gaps.add(MinuteGap(cursor, start));
    if (end > cursor) cursor = end;
  }
  if (cursor < to) gaps.add(MinuteGap(cursor, to));
  return gaps;
}

/// Planned minutes without double counting overlaps.
int plannedMinutes(Iterable<CalendarEntry> entries) {
  final intervals = entries.where((entry) => !entry.isExecuted).toList()
    ..sort(_compareEntries);
  var total = 0;
  var cursor = 0;
  for (final entry in intervals) {
    final start = entry.startMinute < cursor ? cursor : entry.startMinute;
    if (entry.endMinute > start) {
      total += entry.endMinute - start;
      cursor = entry.endMinute;
    }
  }
  return total;
}

int executedMinutes(Iterable<CalendarEntry> entries) => entries
    .where((entry) => entry.isExecuted)
    .fold<int>(0, (sum, entry) => sum + entry.durationMinutes);

/// Number of overlapping pairs among planned commitments. Overlap can be
/// intentional, so the UI reports it instead of blocking the edit.
int conflictCount(Iterable<CalendarEntry> entries) {
  final planned = entries.where((entry) => !entry.isExecuted).toList()
    ..sort(_compareEntries);
  var count = 0;
  for (var i = 0; i < planned.length; i++) {
    for (var j = i + 1; j < planned.length; j++) {
      if (planned[j].startMinute >= planned[i].endMinute) break;
      count++;
    }
  }
  return count;
}

final class DaySummary {
  const DaySummary({
    required this.planned,
    required this.executed,
    required this.free,
    required this.conflicts,
    required this.entries,
  });

  final int planned;
  final int executed;
  final int free;
  final int conflicts;
  final int entries;

  static DaySummary of(Iterable<CalendarEntry> entries) {
    final list = entries.toList();
    return DaySummary(
      planned: plannedMinutes(list),
      executed: executedMinutes(list),
      free: plannedGaps(list).fold<int>(0, (sum, gap) => sum + gap.minutes),
      conflicts: conflictCount(list),
      entries: list.length,
    );
  }
}

/// Monday-first week containing [date].
List<DateTime> weekDays(DateTime date) {
  final day = DateTime(date.year, date.month, date.day);
  final monday = day.subtract(Duration(days: day.weekday - 1));
  return List<DateTime>.generate(
    7,
    (index) => DateTime(monday.year, monday.month, monday.day + index),
  );
}

/// Six Monday-first weeks covering [month]. Always 42 days so the grid height
/// does not jump between months.
List<DateTime> monthGridDays(DateTime month) {
  final first = DateTime(month.year, month.month, 1);
  final start = first.subtract(Duration(days: first.weekday - 1));
  return List<DateTime>.generate(
    42,
    (index) => DateTime(start.year, start.month, start.day + index),
  );
}

bool isSameLocalDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

String localDateKey(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
