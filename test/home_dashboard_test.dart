import 'package:flutter_test/flutter_test.dart';
import 'package:orva/core/domain/home_dashboard.dart';

void main() {
  test('weekly activity uses the rolling seven local days', () {
    final weekly = buildWeeklyActivity(
      today: DateTime(2026, 11, 17),
      executionMinutesByDay: const {'2026-11-17': 40, '2026-11-15': 30},
      studyMinutesByDay: const {'2026-11-17': 25},
      hobbyMinutesByDay: const {'2026-11-13': 60},
    );

    expect(weekly.start, DateTime(2026, 11, 11));
    expect(weekly.end, DateTime(2026, 11, 17));
    expect(weekly.days, hasLength(7));
    expect(weekly.days.first.day, DateTime(2026, 11, 11));
    expect(weekly.days.last.day, DateTime(2026, 11, 17));
    expect(weekly.totalMinutes, 155);
    expect(weekly.activeDays, 3);
    expect(weekly.maxDayMinutes, 65);
    expect(weekly.averageActiveMinutes, closeTo(51.67, 0.01));
    expect(weekly.hasEvidence, isTrue);
    expect(weekly.days.last.executionMinutes, 40);
    expect(weekly.days.last.studyMinutes, 25);
    expect(weekly.days.last.hobbyMinutes, 0);
    expect(weekly.days[2].totalMinutes, 60);
  });

  test('weekly activity keeps missing days empty instead of fake zeroes', () {
    final weekly = buildWeeklyActivity(
      today: DateTime(2026, 1, 2),
      executionMinutesByDay: const {},
      studyMinutesByDay: const {},
      hobbyMinutesByDay: const {},
    );

    expect(weekly.start, DateTime(2025, 12, 27));
    expect(weekly.end, DateTime(2026, 1, 2));
    expect(weekly.days.every((day) => !day.hasActivity), isTrue);
    expect(weekly.totalMinutes, 0);
    expect(weekly.activeDays, 0);
    expect(weekly.averageActiveMinutes, 0);
    expect(weekly.hasEvidence, isFalse);
  });
}
