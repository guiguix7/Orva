import 'package:drift/drift.dart';

import '../domain/calendar_layout.dart';
import 'executions_repository.dart';
import 'nutrition_repository.dart';
import 'obligations_repository.dart';
import 'orva_repository.dart';

/// Read model for the calendar. It never writes schedule data: routine blocks
/// stay owned by the routine repository, obligations by obligations, meals by
/// nutrition and executions by executions. This layer only merges them into one
/// projection so the calendar is a view, not a second source of truth.
extension CalendarRepository on OrvaRepository {
  Future<List<CalendarEntry>> loadCalendarEntries(DateTime date) async {
    final results = await Future.wait<Object?>([
      getRoutineForDate(date),
      getObligationTimeBlocksForDate(date),
      getMealPlanTimeBlocksForDate(date),
      getExecutions(from: date, to: date),
    ]);
    final entries = <CalendarEntry>[];
    for (final row in results[0] as List<Map<String, Object?>>) {
      final entry = _planned(
        row,
        CalendarEntryKind.plannedBlock,
        sourceId: row['id'] as String?,
      );
      if (entry != null) entries.add(entry);
    }
    for (final row in results[1] as List<Map<String, Object?>>) {
      final entry = _planned(
        row,
        CalendarEntryKind.obligation,
        status: row['obligation_status'] as String?,
        sourceId: row['obligation_rule_id'] as String?,
      );
      if (entry != null) entries.add(entry);
    }
    for (final row in results[2] as List<Map<String, Object?>>) {
      final entry = _planned(
        row,
        CalendarEntryKind.mealPlan,
        sourceId: row['meal_plan_id'] as String?,
      );
      if (entry != null) entries.add(entry);
    }
    for (final row in results[3] as List<Map<String, Object?>>) {
      final entry = _execution(row, date);
      if (entry != null) entries.add(entry);
    }
    entries.sort((a, b) => a.startMinute.compareTo(b.startMinute));
    return entries;
  }

  /// Loads a Monday-first week. Each day is resolved independently so
  /// recurrence, exceptions and overnight obligations stay correct.
  Future<Map<String, List<CalendarEntry>>> loadCalendarWeek(
    DateTime date,
  ) async {
    final days = weekDays(date);
    final loaded = await Future.wait(days.map(loadCalendarEntries));
    return {
      for (var index = 0; index < days.length; index++)
        localDateKey(days[index]): loaded[index],
    };
  }

  /// Activity counts used for the discreet month indicators. Planned routine
  /// blocks and real executions only: obligations are generated per day and are
  /// intentionally excluded from this cheap projection.
  Future<Map<String, int>> loadMonthActivity(DateTime month) async {
    final grid = monthGridDays(month);
    final counts = <String, int>{for (final day in grid) localDateKey(day): 0};
    final blocks = await getRoutineBlocks();
    for (final day in grid) {
      final key = localDateKey(day);
      var count = 0;
      for (final block in blocks) {
        final matches = block['block_kind'] == 'weekday'
            ? (block['weekday'] as num?)?.toInt() == day.weekday
            : block['specific_date'] == key;
        if (matches) count++;
      }
      counts[key] = count;
    }
    final executions = await rows(
      'SELECT reference_date, COUNT(*) AS n FROM executions WHERE reference_date>=? AND reference_date<=? GROUP BY reference_date',
      [
        Variable.withString(localDateKey(grid.first)),
        Variable.withString(localDateKey(grid.last)),
      ],
    );
    for (final row in executions) {
      final key = row['reference_date'] as String?;
      if (key == null) continue;
      counts[key] = (counts[key] ?? 0) + ((row['n'] as num?)?.toInt() ?? 0);
    }
    return counts;
  }

  Future<Map<String, Object?>?> findRoutineBlock(String id) async {
    final result = await rows(
      '''SELECT rb.*, g.title AS goal_title, h.name AS hobby_name FROM routine_blocks rb
      LEFT JOIN goals g ON g.id=rb.goal_id LEFT JOIN hobbies h ON h.id=rb.hobby_id
      WHERE rb.id=?''',
      [Variable.withString(id)],
    );
    return result.isEmpty ? null : result.first;
  }

  CalendarEntry? _planned(
    Map<String, Object?> row,
    CalendarEntryKind kind, {
    String? status,
    String? sourceId,
  }) {
    final start = (row['start_minute'] as num?)?.toInt();
    final end = (row['end_minute'] as num?)?.toInt();
    if (start == null ||
        end == null ||
        start < 0 ||
        end > 1440 ||
        end <= start) {
      return null;
    }
    final title = (row['title'] as String?)?.trim();
    final category = (row['category'] as String?)?.trim();
    return CalendarEntry(
      id: '${kind.name}:${row['id']}',
      kind: kind,
      title: title == null || title.isEmpty ? 'Sem título' : title,
      category: category == null || category.isEmpty
          ? 'Sem categoria'
          : category,
      startMinute: start,
      endMinute: end,
      status: status,
      sourceId: sourceId,
    );
  }

  CalendarEntry? _execution(Map<String, Object?> row, DateTime date) {
    final duration = (row['duration_minutes'] as num?)?.toInt() ?? 0;
    if (duration <= 0) return null;
    final startedAt = DateTime.tryParse((row['started_at'] as String?) ?? '')
        ?.toLocal();
    var start = startedAt != null && isSameLocalDay(startedAt, date)
        ? startedAt.hour * 60 + startedAt.minute
        : 0;
    if (start >= 1440) start = 0;
    final end = (start + duration).clamp(start + 1, 1440);
    final title = (row['title'] as String?)?.trim();
    final category = (row['category'] as String?)?.trim();
    return CalendarEntry(
      id: 'execution:${row['id']}',
      kind: CalendarEntryKind.execution,
      title: title == null || title.isEmpty ? 'Atividade executada' : title,
      category: category == null || category.isEmpty
          ? 'Sem categoria'
          : category,
      startMinute: start,
      endMinute: end,
      sourceId: null,
    );
  }
}
