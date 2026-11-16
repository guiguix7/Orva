import 'package:flutter_test/flutter_test.dart';
import 'package:orva/core/domain/calendar_layout.dart';
import 'package:orva/core/domain/home_overview.dart';

CalendarEntry _planned(
  String id,
  int start,
  int end, {
  CalendarEntryKind kind = CalendarEntryKind.plannedBlock,
  String? status,
}) => CalendarEntry(
  id: id,
  kind: kind,
  title: id,
  category: 'Trabalho',
  startMinute: start,
  endMinute: end,
  status: status,
);

CalendarEntry _execution(String id, int start, int end) => CalendarEntry(
  id: id,
  kind: CalendarEntryKind.execution,
  title: id,
  category: 'Estudo',
  startMinute: start,
  endMinute: end,
);

void main() {
  group('HomeOverview', () {
    final now = DateTime(2026, 11, 16, 10, 30);
    final overview = HomeOverview.build(
      now: now,
      entries: [
        _execution('Leitura', 8 * 60, 8 * 60 + 45),
        _planned('Foco', 9 * 60, 10 * 60),
        _planned('Reunião', 10 * 60, 11 * 60),
        _planned('Almoço', 11 * 60 + 30, 12 * 60 + 30),
      ],
    );

    test('classifies live, next, past and realized entries', () {
      HomeEntryPhase phaseOf(String id) =>
          overview.items.firstWhere((item) => item.entry.id == id).phase;

      expect(phaseOf('Leitura'), HomeEntryPhase.realized);
      expect(phaseOf('Foco'), HomeEntryPhase.past);
      expect(phaseOf('Reunião'), HomeEntryPhase.live);
      expect(phaseOf('Almoço'), HomeEntryPhase.upcoming);
      expect(overview.liveActivity?.id, 'Reunião');
      expect(overview.nextActivity?.id, 'Almoço');
    });

    test('keeps planned and executed time separate', () {
      expect(overview.plannedMinutes, 180);
      expect(overview.executedMinutes, 45);
      expect(overview.executionCoverage, closeTo(0.25, 0.0001));
      expect(overview.freeMinutes, 1440 - 180);
      expect(overview.remainingPlannedMinutes, 120 + 60);
      expect(overview.executionCount, 1);
      expect(overview.plannedBlockCount, 3);
    });

    test('ends the day with no next activity', () {
      final evening = HomeOverview.build(
        now: DateTime(2026, 11, 16, 22),
        entries: [_planned('Foco', 9 * 60, 10 * 60)],
      );
      expect(evening.liveActivity, isNull);
      expect(evening.nextActivity, isNull);
      expect(evening.remainingPlannedMinutes, 0);
    });

    test('does not count overlapping planned time twice', () {
      final overlap = HomeOverview.build(
        now: DateTime(2026, 11, 16, 7),
        entries: [
          _planned('A', 8 * 60, 10 * 60),
          _planned('B', 9 * 60, 11 * 60),
        ],
      );
      expect(overlap.plannedMinutes, 180);
      expect(overlap.conflictCount, 1);
    });

    test('reports only obligations still pending', () {
      final day = HomeOverview.build(
        now: DateTime(2026, 11, 16, 9),
        entries: [
          _planned(
            'Conta de luz',
            8 * 60,
            8 * 60 + 15,
            kind: CalendarEntryKind.obligation,
            status: 'planned',
          ),
          _planned(
            'Remédio',
            9 * 60,
            9 * 60 + 10,
            kind: CalendarEntryKind.obligation,
            status: 'completed',
          ),
        ],
      );
      expect(day.pendingObligations.map((entry) => entry.title), ['Conta de luz']);
    });

    test('suggests a new block inside the first free window', () {
      final day = HomeOverview.build(
        now: DateTime(2026, 11, 16, 9, 30),
        entries: [
          _planned('Foco', 9 * 60, 10 * 60),
          _planned('Reunião', 11 * 60, 12 * 60),
        ],
      );
      expect(day.suggestedBlockStart, 10 * 60);
    });

    test('rounds the suggested start to a quarter hour', () {
      final day = HomeOverview.build(
        now: DateTime(2026, 11, 16, 9, 31),
        entries: const [],
      );
      expect(day.suggestedBlockStart, 9 * 60 + 45);
    });

    test('has no coverage when nothing was planned', () {
      final day = HomeOverview.build(
        now: DateTime(2026, 11, 16, 9),
        entries: [_execution('Leitura', 8 * 60, 9 * 60)],
      );
      expect(day.executionCoverage, isNull);
      expect(day.hasEntries, isTrue);
      expect(day.hasPlan, isFalse);
    });

    test('timeline exposes long free windows between planned entries', () {
      final day = HomeOverview.build(
        now: DateTime(2026, 11, 16, 8),
        entries: [
          _planned('Foco', 8 * 60, 9 * 60),
          _planned('Reunião', 13 * 60, 14 * 60),
        ],
      );
      final gap = day.timeline.whereType<HomeGapSlot>().first;
      expect(gap.startMinute, 9 * 60);
      expect(gap.endMinute, 13 * 60);
      expect(gap.minutes, 240);
    });
  });

  group('buildHabitReport', () {
    test('counts eligible opportunities, not app opens', () {
      final habit = const HabitRecord(
        id: 'h1',
        name: 'Leitura',
        unit: 'páginas',
        target: 20,
        activeWeekdays: {1, 3, 5},
      );
      final report = buildHabitReport(
        habits: [habit],
        logsByHabit: {
          'h1': {'2026-11-09': 12, '2026-11-13': 24, '2026-11-14': 0},
        },
        windowStart: DateTime(2026, 11, 9),
        today: DateTime(2026, 11, 15),
      );
      final signal = report.signals.single;
      expect(signal.eligibleDays, 3);
      expect(signal.loggedDays, 2);
      expect(signal.consistency, closeTo(2 / 3, 0.0001));
      expect(signal.todayQuantity, 0);
      expect(report.eligibleDays, 3);
      expect(report.loggedDays, 2);
    });

    test('returns null consistency when no day is eligible', () {
      final report = buildHabitReport(
        habits: const [
          HabitRecord(
            id: 'h1',
            name: 'Meditação',
            unit: 'min',
            activeWeekdays: {1},
          ),
        ],
        logsByHabit: const {'h1': {}},
        windowStart: DateTime(2026, 11, 15),
        today: DateTime(2026, 11, 15),
      );
      expect(report.signals.single.consistency, isNull);
      expect(report.consistency, isNull);
      expect(report.eligibleDays, 0);
    });

    test('treats an empty weekday set as every day', () {
      final report = buildHabitReport(
        habits: const [
          HabitRecord(id: 'h1', name: 'Água', unit: 'copos'),
        ],
        logsByHabit: {
          'h1': {'2026-11-15': 8},
        },
        windowStart: DateTime(2026, 11, 14),
        today: DateTime(2026, 11, 15),
      );
      expect(report.eligibleDays, 2);
      expect(report.loggedDays, 1);
      expect(report.signals.single.isTodayLogged, isTrue);
      expect(report.signals.single.todayQuantity, 8);
    });

    test('caps the window at today', () {
      final report = buildHabitReport(
        habits: const [HabitRecord(id: 'h1', name: 'Água', unit: 'copos')],
        logsByHabit: {
          'h1': {'2026-11-17': 4},
        },
        windowStart: DateTime(2026, 11, 16),
        today: DateTime(2026, 11, 16),
      );
      expect(report.eligibleDays, 1);
      expect(report.signals.single.days, hasLength(1));
    });
  });

  group('ChecklistDigest', () {
    test('has no ratio without items', () {
      expect(ChecklistDigest.empty.ratio, isNull);
      expect(ChecklistDigest.empty.remaining, 0);
    });

    test('reports completed and remaining items', () {
      const digest = ChecklistDigest(completed: 3, total: 4);
      expect(digest.ratio, 0.75);
      expect(digest.remaining, 1);
    });
  });
}
