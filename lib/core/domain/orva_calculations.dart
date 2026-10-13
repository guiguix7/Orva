/// Pure calendar and time calculations used by forms and dashboards.
/// No widget or database dependency: deterministic and unit-testable.
library;

DateTime addCalendarMonths(DateTime date, int months) {
  final first = DateTime(date.year, date.month + months, 1);
  final last = DateTime(first.year, first.month + 1, 0).day;
  final day = date.day < last ? date.day : last;
  return DateTime(first.year, first.month, day);
}

/// Greeting for local device hour, matching Orva's 05:00/12:00/18:00 boundaries.
/// Hours outside 0..23 are rejected so invalid clocks cannot silently show a greeting.
String greetingForHour(int hour) {
  if (hour < 0 || hour > 23) throw RangeError.range(hour, 0, 23, 'hour');
  if (hour >= 5 && hour < 12) return 'Bom dia';
  if (hour >= 12 && hour < 18) return 'Boa tarde';
  return 'Boa noite';
}

DateTime? suggestedGoalDeadline(String period, DateTime start) => switch (period) {
  'daily' => DateTime(start.year, start.month, start.day),
  'weekly' => DateTime(start.year, start.month, start.day + 7),
  'monthly' => addCalendarMonths(start, 1),
  'quarterly' => addCalendarMonths(start, 3),
  'yearly' => addCalendarMonths(start, 12),
  _ => null,
};

class PlannedInterval {
  const PlannedInterval(this.startMinute, this.endMinute, this.category, this.title);
  final int startMinute;
  final int endMinute;
  final String category;
  final String title;
}

/// The planned occupation of a local 24-hour wall-clock day, without double
/// counting overlapping intervals.  Does not imply time was actually spent.
int occupiedMinutes(Iterable<PlannedInterval> intervals) {
  final sorted = intervals
      .map((e) => (start: e.startMinute.clamp(0, 1440).toInt(), end: e.endMinute.clamp(0, 1440).toInt()))
      .where((e) => e.end > e.start)
      .toList()
    ..sort((a, b) => a.start.compareTo(b.start));
  var total = 0;
  var end = 0;
  for (final interval in sorted) {
    final from = interval.start > end ? interval.start : end;
    if (interval.end > from) total += interval.end - from;
    if (interval.end > end) end = interval.end;
  }
  return total;
}

/// Category totals, with overlaps assigned to the earliest starting block;
/// ties retain the input order. Totals always match the occupied minutes.
Map<String, int> categoryMinutes(Iterable<PlannedInterval> intervals) {
  final blocks = intervals.toList();
  final totals = <String, int>{};
  for (var minute = 0; minute < 1440; minute++) {
    PlannedInterval? best;
    for (final block in blocks) {
      if (block.startMinute <= minute && block.endMinute > minute &&
          (best == null || block.startMinute < best.startMinute)) {
        best = block;
      }
    }
    if (best != null) totals[best.category] = (totals[best.category] ?? 0) + 1;
  }
  return totals;
}

bool isNightTheme(DateTime localTime, {int dayStartHour = 7, int nightStartHour = 19}) {
  final minute = localTime.hour * 60 + localTime.minute;
  final dayStart = dayStartHour * 60;
  final nightStart = nightStartHour * 60;
  return minute < dayStart || minute >= nightStart;
}
