import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orva/core/database/app_database.dart';
import 'package:orva/core/database/calendar_repository.dart';
import 'package:orva/core/database/executions_repository.dart';
import 'package:orva/core/database/nutrition_repository.dart';
import 'package:orva/core/database/orva_repository.dart';
import 'package:orva/core/domain/calendar_layout.dart';

void main() {
  late AppDatabase database;
  late OrvaRepository repository;
  final date = DateTime(2026, 11, 18);

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    repository = OrvaRepository(database);
  });

  tearDown(() async {
    await database.close();
  });

  test(
    'merges routine, meals and executions without duplicating records',
    () async {
      await repository.saveRoutineBlock(
        title: 'Trabalho',
        category: 'Trabalho',
        startMinute: 8 * 60,
        endMinute: 12 * 60,
        blockKind: 'date',
        specificDate: repository.dateKey(date),
      );
      await repository.saveMealPlan(
        title: 'Almoço',
        mealType: 'lunch',
        recurrence: 'once',
        plannedDate: repository.dateKey(date),
        plannedMinute: 12 * 60,
        durationMinutes: 60,
      );
      await repository.saveExecution(
        title: 'Estudo',
        category: 'Estudo',
        startedAt: DateTime(2026, 11, 18, 19),
        durationMinutes: 40,
        referenceDate: date,
      );

      final entries = await repository.loadCalendarEntries(date);
      final kinds = entries.map((entry) => entry.kind).toSet();
      final summary = DaySummary.of(entries);

      expect(
        kinds,
        containsAll(<CalendarEntryKind>[
          CalendarEntryKind.plannedBlock,
          CalendarEntryKind.mealPlan,
          CalendarEntryKind.execution,
        ]),
      );
      expect(summary.planned, 300);
      expect(summary.executed, 40);
      expect(summary.conflicts, 0);
      // One source record each: nothing was copied into the calendar.
      expect((await repository.getRoutineBlocks()).length, 1);
      expect((await repository.getMealPlans()).length, 1);
      expect((await repository.getExecutions(from: date, to: date)).length, 1);
    },
  );

  test('only the selected local day is loaded', () async {
    await repository.saveRoutineBlock(
      title: 'Segunda',
      category: 'Trabalho',
      startMinute: 8 * 60,
      endMinute: 9 * 60,
      blockKind: 'weekday',
      weekday: 3, // Wednesday
    );
    await repository.saveRoutineBlock(
      title: 'Data única',
      category: 'Trabalho',
      startMinute: 10 * 60,
      endMinute: 11 * 60,
      blockKind: 'date',
      specificDate: repository.dateKey(date),
    );

    final entries = await repository.loadCalendarEntries(date);

    expect(
      entries.map((entry) => entry.title),
      containsAll(['Segunda', 'Data única']),
    );
    expect(
      await repository.loadCalendarEntries(date.add(const Duration(days: 1))),
      isEmpty,
    );
  });

  test(
    'a week loads seven distinct days and month counts stay discrete',
    () async {
      await repository.saveRoutineBlock(
        title: 'Rotina',
        category: 'Trabalho',
        startMinute: 8 * 60,
        endMinute: 9 * 60,
        blockKind: 'weekday',
        weekday: 3,
      );

      final week = await repository.loadCalendarWeek(date);
      expect(week.length, 7);
      expect(week[localDateKey(date)]!.length, 1);

      final counts = await repository.loadMonthActivity(date);
      expect(counts.length, 42);
      expect(counts[localDateKey(date)], 1);
      expect(counts[localDateKey(DateTime(2026, 11, 19))], 0);
    },
  );
}
