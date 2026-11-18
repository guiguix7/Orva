import 'calendar_layout.dart';

/// Real activity for one local day. Every value is a sum of duration records
/// owned by its module; planned time never enters this projection.
final class DailyActivity {
  const DailyActivity({
    required this.day,
    required this.executionMinutes,
    required this.studyMinutes,
    required this.hobbyMinutes,
  });

  final DateTime day;
  final int executionMinutes;
  final int studyMinutes;
  final int hobbyMinutes;

  int get totalMinutes => executionMinutes + studyMinutes + hobbyMinutes;

  bool get hasActivity => totalMinutes > 0;
}

/// Rolling seven-day activity window used by the Home weekly chart.
final class WeeklyActivity {
  const WeeklyActivity({
    required this.start,
    required this.end,
    required this.days,
  });

  final DateTime start;
  final DateTime end;
  final List<DailyActivity> days;

  int get totalMinutes =>
      days.fold<int>(0, (total, day) => total + day.totalMinutes);

  int get activeDays => days.where((day) => day.hasActivity).length;

  int get maxDayMinutes => days.fold<int>(
    0,
    (max, day) => day.totalMinutes > max ? day.totalMinutes : max,
  );

  /// Average over days that actually recorded activity. Days without records
  /// stay out of the denominator, so a missing log is not treated as zero.
  double get averageActiveMinutes =>
      activeDays == 0 ? 0 : totalMinutes / activeDays;

  bool get hasEvidence => totalMinutes > 0;
}

/// Builds the rolling window ending today (inclusive), using local dates.
///
/// [executionMinutesByDay], [studyMinutesByDay] and [hobbyMinutesByDay] are
/// keyed by `yyyy-MM-dd` and must already exclude cross-module duplicates.
WeeklyActivity buildWeeklyActivity({
  required DateTime today,
  required Map<String, int> executionMinutesByDay,
  required Map<String, int> studyMinutesByDay,
  required Map<String, int> hobbyMinutesByDay,
}) {
  final end = DateTime(today.year, today.month, today.day);
  final start = DateTime(end.year, end.month, end.day - 6);
  final days = <DailyActivity>[];
  for (var offset = 0; offset < 7; offset++) {
    final day = DateTime(start.year, start.month, start.day + offset);
    final key = localDateKey(day);
    days.add(
      DailyActivity(
        day: day,
        executionMinutes: executionMinutesByDay[key] ?? 0,
        studyMinutes: studyMinutesByDay[key] ?? 0,
        hobbyMinutes: hobbyMinutesByDay[key] ?? 0,
      ),
    );
  }
  return WeeklyActivity(start: start, end: end, days: List.unmodifiable(days));
}
