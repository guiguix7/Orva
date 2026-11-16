import 'package:flutter_test/flutter_test.dart';
import 'package:orva/core/domain/calendar_layout.dart';

CalendarEntry _entry(
  String id,
  int start,
  int end, {
  CalendarEntryKind kind = CalendarEntryKind.plannedBlock,
  String category = 'Trabalho',
}) => CalendarEntry(
  id: id,
  kind: kind,
  title: id,
  category: category,
  startMinute: start,
  endMinute: end,
);

void main() {
  group('calendar layout', () {
    test('non-overlapping entries keep full width', () {
      final positioned = layoutDayLanes([
        _entry('a', 8 * 60, 9 * 60),
        _entry('b', 9 * 60, 10 * 60),
      ]);

      expect(positioned.every((item) => item.laneCount == 1), isTrue);
      expect(positioned.every((item) => item.lane == 0), isTrue);
    });

    test('overlapping entries share the width side by side', () {
      final positioned = layoutDayLanes([
        _entry('a', 8 * 60, 10 * 60),
        _entry('b', 9 * 60, 11 * 60),
      ]);

      expect(positioned.map((item) => item.lane).toSet(), {0, 1});
      expect(positioned.every((item) => item.laneCount == 2), isTrue);
    });

    test('separate clusters are laid out independently', () {
      final positioned = layoutDayLanes([
        _entry('a', 8 * 60, 10 * 60),
        _entry('b', 9 * 60, 11 * 60),
        _entry('c', 14 * 60, 15 * 60),
      ]);
      final third = positioned.firstWhere((item) => item.entry.id == 'c');

      expect(third.laneCount, 1);
      expect(third.lane, 0);
    });

    test('planned minutes never double count an overlap', () {
      final entries = [
        _entry('a', 8 * 60, 10 * 60),
        _entry('b', 9 * 60, 11 * 60),
      ];

      expect(plannedMinutes(entries), 180);
      expect(conflictCount(entries), 1);
    });

    test('executions are measured separately from planned time', () {
      final entries = [
        _entry('a', 8 * 60, 10 * 60),
        _entry('run', 8 * 60, 9 * 60, kind: CalendarEntryKind.execution),
      ];
      final summary = DaySummary.of(entries);

      expect(summary.planned, 120);
      expect(summary.executed, 60);
      expect(plannedMinutes(entries), 120);
    });

    test('free gaps describe unplanned time and ignore executions', () {
      final entries = [
        _entry('a', 8 * 60, 9 * 60),
        _entry('run', 10 * 60, 11 * 60, kind: CalendarEntryKind.execution),
      ];
      final gaps = plannedGaps(entries);

      expect(gaps.first.startMinute, 0);
      expect(gaps.first.endMinute, 8 * 60);
      // 09:00 onward stays free: an execution is spent time, not planned time.
      expect(
        gaps.any(
          (gap) => gap.startMinute == 9 * 60 && gap.endMinute == 1440,
        ),
        isTrue,
      );
      expect(DaySummary.of(entries).free, 480 + 900);
    });

    test('an overnight entry is clamped by the day boundaries', () {
      final entry = _entry('night', 23 * 60, 24 * 60);
      expect(entry.durationMinutes, 60);
    });

    test('invalid intervals are rejected', () {
      expect(() => _entry('bad', 600, 600), throwsArgumentError);
      expect(() => _entry('bad', -1, 60), throwsArgumentError);
      expect(() => _entry('bad', 60, 1500), throwsArgumentError);
    });

    test('week starts on Monday and always has seven days', () {
      final week = weekDays(DateTime(2026, 11, 18));
      expect(week.length, 7);
      expect(week.first.weekday, DateTime.monday);
      expect(week.last.weekday, DateTime.sunday);
      expect(isSameLocalDay(week.first, DateTime(2026, 11, 16)), isTrue);
    });

    test('month grid always covers six weeks starting on Monday', () {
      final grid = monthGridDays(DateTime(2026, 2, 10));
      expect(grid.length, 42);
      expect(grid.first.weekday, DateTime.monday);
      expect(grid.any((day) => day.month == 2 && day.day == 10), isTrue);
    });

    test('local date key is a date-only string', () {
      expect(localDateKey(DateTime(2026, 3, 5)), '2026-03-05');
      expect(localDateKey(DateTime(2026, 12, 31)), '2026-12-31');
    });
  });
}
