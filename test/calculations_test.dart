import 'package:flutter_test/flutter_test.dart';
import 'package:orva/core/domain/orva_calculations.dart';

void main() {
  test('goal deadlines use calendar months and handle leap years', () {
    expect(suggestedGoalDeadline('yearly', DateTime(2024, 2, 29)), DateTime(2025, 2, 28));
    expect(suggestedGoalDeadline('monthly', DateTime(2026, 1, 31)), DateTime(2026, 2, 28));
    expect(suggestedGoalDeadline('quarterly', DateTime(2026, 11, 30)), DateTime(2027, 2, 28));
    expect(suggestedGoalDeadline('weekly', DateTime(2026, 12, 29)), DateTime(2027, 1, 5));
    expect(suggestedGoalDeadline('open', DateTime(2026)), isNull);
  });

  test('overlapping activities never create more than 24 hours', () {
    const blocks = [
      PlannedInterval(0, 480, 'Sono', 'Descanso'),
      PlannedInterval(420, 1080, 'Escola', 'Aulas'),
    ];
    expect(occupiedMinutes(blocks), 1080);
    expect(categoryMinutes(blocks), {'Sono': 480, 'Escola': 600});
    expect(1440 - occupiedMinutes(blocks), 360);
    expect(occupiedMinutes([const PlannedInterval(-500, 2000, 'Teste', 'Teste')]), 1440);
    expect(occupiedMinutes(const []), 0);
  });

  test('greeting uses morning, afternoon, and night boundaries correctly', () {
    expect(greetingForHour(0), 'Boa noite');
    expect(greetingForHour(4), 'Boa noite');
    expect(greetingForHour(5), 'Bom dia');
    expect(greetingForHour(11), 'Bom dia');
    expect(greetingForHour(12), 'Boa tarde');
    expect(greetingForHour(17), 'Boa tarde');
    expect(greetingForHour(18), 'Boa noite');
    expect(greetingForHour(23), 'Boa noite');
  });

  test('theme changes based on local time', () {
    expect(isNightTheme(DateTime(2026, 10, 12, 6, 59)), true);
    expect(isNightTheme(DateTime(2026, 10, 12, 7)), false);
    expect(isNightTheme(DateTime(2026, 10, 12, 18, 59)), false);
    expect(isNightTheme(DateTime(2026, 10, 12, 19)), true);
  });
}
