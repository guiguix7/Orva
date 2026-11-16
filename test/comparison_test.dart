import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orva/core/database/app_database.dart';
import 'package:orva/core/database/comparison_repository.dart';
import 'package:orva/core/database/habits_repository.dart';
import 'package:orva/core/database/orva_repository.dart';
import 'package:orva/core/database/study_repository.dart';
import 'package:orva/core/domain/comparison_scoring.dart';

void main() {
  group('comparison scoring', () {
    final window = DateRange(DateTime(2026, 11, 1), DateTime(2026, 11, 30));

    test('reaching the threshold favors the configured side', () {
      final rule = TraitRule(
        side: ComparisonSide.alfredo,
        measurement: TraitMeasurement.manualCheckin,
        threshold: 3,
      );

      expect(
        evaluateTrait(
          traitId: 't',
          rule: rule,
          measuredValue: 3,
          window: window,
        ).outcome,
        TraitOutcome.favorsAlfredo,
      );
      expect(
        evaluateTrait(
          traitId: 't',
          rule: rule,
          measuredValue: 2,
          window: window,
        ).outcome,
        TraitOutcome.neutral,
      );
      expect(
        evaluateTrait(
          traitId: 't',
          rule: rule,
          measuredValue: null,
          window: window,
        ).outcome,
        TraitOutcome.unknown,
      );
    });

    test(
      'a Beto-targeted trait favors Beto only when its threshold is reached',
      () {
        final rule = TraitRule(
          side: ComparisonSide.beto,
          measurement: TraitMeasurement.manualCheckin,
          threshold: 4,
        );

        expect(
          evaluateTrait(
            traitId: 't',
            rule: rule,
            measuredValue: 5,
            window: window,
          ).outcome,
          TraitOutcome.favorsBeto,
        );
        expect(
          evaluateTrait(
            traitId: 't',
            rule: rule,
            measuredValue: 4,
            window: window,
          ).outcome,
          TraitOutcome.favorsBeto,
        );
        expect(
          evaluateTrait(
            traitId: 't',
            rule: rule,
            measuredValue: 0,
            window: window,
          ).outcome,
          TraitOutcome.neutral,
        );
      },
    );

    test('missing evidence is unknown and never counted for either side', () {
      final unknown = evaluateTrait(
        traitId: 't',
        rule: TraitRule(
          side: ComparisonSide.alfredo,
          measurement: TraitMeasurement.habitQuantity,
          threshold: 5,
        ),
        measuredValue: null,
        window: window,
      );
      final summary = summarizeComparison([unknown]);

      expect(summary.hasEvidence, isFalse);
      expect(summary.alfredoShare, isNull);
      expect(summary.betoShare, isNull);
      expect(summary.unknownTraits, 1);
      expect(summary.assessedTraits, 0);
      expect(summary.coverage, 0);
    });

    test(
      'weights define the shares and neutral/unknown leave the denominator',
      () {
        final evaluations = [
          evaluateTrait(
            traitId: 'a1',
            rule: TraitRule(
              side: ComparisonSide.alfredo,
              measurement: TraitMeasurement.manualCheckin,
              threshold: 1,
              weight: 2,
            ),
            measuredValue: 5,
            window: window,
          ),
          evaluateTrait(
            traitId: 'b1',
            rule: TraitRule(
              side: ComparisonSide.beto,
              measurement: TraitMeasurement.manualCheckin,
              threshold: 1,
              weight: 2,
            ),
            measuredValue: 5,
            window: window,
          ),
          evaluateTrait(
            traitId: 'neutral',
            rule: TraitRule(
              side: ComparisonSide.alfredo,
              measurement: TraitMeasurement.manualCheckin,
              threshold: 10,
              weight: 5,
            ),
            measuredValue: 1,
            window: window,
          ),
          evaluateTrait(
            traitId: 'unknown',
            rule: TraitRule(
              side: ComparisonSide.alfredo,
              measurement: TraitMeasurement.manualCheckin,
              threshold: 1,
              weight: 5,
            ),
            measuredValue: null,
            window: window,
          ),
        ];
        final summary = summarizeComparison(evaluations);

        // 2 vs 2 is a legitimate even split, not a hard-coded default.
        expect(summary.alfredoWeight, 2);
        expect(summary.betoWeight, 2);
        expect(summary.alfredoShare, 0.5);
        expect(summary.betoShare, 0.5);
        expect(summary.assessedTraits, 2);
        expect(summary.neutralTraits, 1);
        expect(summary.unknownTraits, 1);
        expect(summary.activeTraits, 4);
        expect(summary.coverage, 0.5);
      },
    );

    test('current week starts on Monday and ends today', () {
      final today = DateTime(2026, 11, 18);
      final result = resolveComparisonWindow(
        traitWindowDays: 0,
        selected: ComparisonPeriod.currentWeek,
        today: today,
      );

      expect(result.start.weekday, DateTime.monday);
      expect(result.end, DateTime(2026, 11, 18));
      expect(result.days, today.weekday);
    });

    test('trailing windows and the current month include today', () {
      final today = DateTime(2026, 11, 18);
      final last7 = resolveComparisonWindow(
        traitWindowDays: 0,
        selected: ComparisonPeriod.last7Days,
        today: today,
      );
      expect(last7.start, DateTime(2026, 11, 12));
      expect(last7.days, 7);

      final last30 = resolveComparisonWindow(
        traitWindowDays: 0,
        selected: ComparisonPeriod.last30Days,
        today: today,
      );
      expect(last30.days, 30);

      final month = resolveComparisonWindow(
        traitWindowDays: 0,
        selected: ComparisonPeriod.currentMonth,
        today: today,
      );
      expect(month.start, DateTime(2026, 11, 1));
      expect(month.end, today);
    });

    test('a trait window overrides the selected period', () {
      final result = resolveComparisonWindow(
        traitWindowDays: 5,
        selected: ComparisonPeriod.last30Days,
        today: DateTime(2026, 11, 18),
      );
      expect(result.start, DateTime(2026, 11, 14));
      expect(result.days, 5);
    });

    test('calendar day counts cross month and leap-day boundaries', () {
      expect(DateRange(DateTime(2024, 2, 28), DateTime(2024, 3, 1)).days, 3);
      expect(DateRange(DateTime(2026, 12, 30), DateTime(2027, 1, 2)).days, 4);
      expect(DateRange(DateTime(2026, 11, 9), DateTime(2026, 11, 9)).days, 1);
    });

    test('invalid rules and measurements are rejected', () {
      expect(
        () => TraitRule(
          side: ComparisonSide.alfredo,
          measurement: TraitMeasurement.manualCheckin,
          threshold: 0,
        ),
        throwsArgumentError,
      );
      expect(
        () => TraitRule(
          side: ComparisonSide.alfredo,
          measurement: TraitMeasurement.manualCheckin,
          threshold: 1,
          weight: double.nan,
        ),
        throwsArgumentError,
      );
      expect(
        () => TraitRule(
          side: ComparisonSide.alfredo,
          measurement: TraitMeasurement.manualCheckin,
          threshold: 1,
          windowDays: 400,
        ),
        throwsArgumentError,
      );
      expect(
        () => evaluateTrait(
          traitId: 't',
          rule: TraitRule(
            side: ComparisonSide.alfredo,
            measurement: TraitMeasurement.manualCheckin,
            threshold: 1,
          ),
          measuredValue: double.infinity,
          window: window,
        ),
        throwsArgumentError,
      );
      expect(
        () => DateRange(DateTime(2026, 11, 10), DateTime(2026, 11, 9)),
        throwsArgumentError,
      );
    });
  });

  group('comparison repository', () {
    late AppDatabase database;
    late OrvaRepository repository;

    setUp(() {
      database = AppDatabase.forTesting(NativeDatabase.memory());
      repository = OrvaRepository(database);
    });

    tearDown(() async {
      await database.close();
    });

    final window = DateRange(DateTime(2026, 11, 1), DateTime(2026, 11, 30));

    test('seeding is idempotent and never creates evidence', () async {
      await repository.ensureComparisonSeeded();

      expect((await repository.getComparisonProfiles()).keys.toSet(), {
        'alfredo',
        'beto',
      });
      expect((await repository.getComparisonTraits()).length, 4);

      await repository.ensureComparisonSeeded();

      expect((await repository.getComparisonProfiles()).length, 2);
      expect((await repository.getComparisonTraits()).length, 4);
      expect(await repository.getComparisonCheckins('tpl_leitura'), isEmpty);
    });

    test('manual check-ins are unique per trait and local day', () async {
      await repository.ensureComparisonSeeded();
      final day = DateTime(2026, 11, 10);

      await repository.setComparisonCheckin(
        traitId: 'tpl_leitura',
        date: day,
        recorded: true,
      );
      await repository.setComparisonCheckin(
        traitId: 'tpl_leitura',
        date: day,
        recorded: true,
      );
      expect((await repository.getComparisonCheckins('tpl_leitura')).length, 1);
      expect(
        await repository.isComparisonCheckedIn('tpl_leitura', day),
        isTrue,
      );

      await repository.toggleComparisonCheckin(
        traitId: 'tpl_leitura',
        date: day,
      );
      expect(
        await repository.isComparisonCheckedIn('tpl_leitura', day),
        isFalse,
      );
      expect((await repository.getComparisonCheckins('tpl_leitura')).length, 0);
    });

    test(
      'manual evidence is unknown without check-ins and counts days otherwise',
      () async {
        await repository.ensureComparisonSeeded();
        final trait = (await repository.getComparisonTraits()).firstWhere(
          (row) => row['id'] == 'tpl_leitura',
        );

        expect(await repository.measureComparisonTrait(trait, window), isNull);

        await repository.setComparisonCheckin(
          traitId: 'tpl_leitura',
          date: DateTime(2026, 11, 10),
          recorded: true,
        );
        await repository.setComparisonCheckin(
          traitId: 'tpl_leitura',
          date: DateTime(2026, 11, 12),
          recorded: true,
        );

        expect(await repository.measureComparisonTrait(trait, window), 2);
      },
    );

    test('habit evidence reuses habit logs without duplicating them', () async {
      await repository.saveHabit(name: 'Cardio', unit: 'vezes');
      final habit = (await repository.getHabits()).single;
      final habitId = habit['id'] as String;
      await repository.logHabit(
        habitId: habitId,
        date: DateTime(2026, 11, 9),
        quantity: 2,
      );
      await repository.logHabit(
        habitId: habitId,
        date: DateTime(2026, 11, 10),
        quantity: 1,
      );

      await repository.saveComparisonTrait(
        label: 'Cardio',
        side: ComparisonSide.alfredo,
        measurement: TraitMeasurement.habitQuantity,
        sourceId: habitId,
        threshold: 3,
        unit: 'vezes',
      );
      final trait = (await repository.getComparisonTraits()).single;

      expect(await repository.measureComparisonTrait(trait, window), 3);
      // The source log remains the only record.
      expect((await repository.getHabitLogs(habitId)).length, 2);
    });

    test(
      'study evidence reuses study sessions and can filter by subject',
      () async {
        await repository.saveStudySubject(name: 'Programação');
        await repository.saveStudySubject(name: 'Idiomas');
        final subjects = await repository.getStudySubjects();
        final programming = subjects.firstWhere(
          (row) => row['name'] == 'Programação',
        );
        final languages = subjects.firstWhere(
          (row) => row['name'] == 'Idiomas',
        );

        await repository.saveStudySession(
          subjectId: programming['id'] as String,
          sessionDate: DateTime(2026, 11, 12),
          durationMinutes: 90,
        );
        await repository.saveStudySession(
          subjectId: languages['id'] as String,
          sessionDate: DateTime(2026, 11, 13),
          durationMinutes: 30,
        );

        await repository.saveComparisonTrait(
          label: 'Estudo de programação',
          side: ComparisonSide.alfredo,
          measurement: TraitMeasurement.studyMinutes,
          sourceId: programming['id'] as String,
          threshold: 60,
          unit: 'min',
        );
        final trait = (await repository.getComparisonTraits()).single;

        expect(await repository.measureComparisonTrait(trait, window), 90);
      },
    );

    test(
      'a sensitive trait is stored disabled and a required source is validated',
      () async {
        await repository.saveComparisonTrait(
          label: 'Rede social em excesso',
          side: ComparisonSide.beto,
          measurement: TraitMeasurement.manualCheckin,
          threshold: 5,
          sensitive: true,
        );
        final trait = (await repository.getComparisonTraits()).single;
        expect(trait['is_sensitive'], 1);
        expect(trait['is_active'], 0);

        await expectLater(
          repository.saveComparisonTrait(
            label: 'Sem origem',
            side: ComparisonSide.alfredo,
            measurement: TraitMeasurement.habitQuantity,
            threshold: 1,
          ),
          throwsArgumentError,
        );
      },
    );

    test(
      'deleting a trait removes its check-ins but not source records',
      () async {
        await repository.saveHabit(name: 'Leitura', unit: 'páginas');
        final habitId = (await repository.getHabits()).single['id'] as String;
        await repository.logHabit(
          habitId: habitId,
          date: DateTime(2026, 11, 10),
          quantity: 10,
        );
        await repository.saveComparisonTrait(
          label: 'Leitura',
          side: ComparisonSide.alfredo,
          measurement: TraitMeasurement.habitQuantity,
          sourceId: habitId,
          threshold: 5,
        );
        final trait = (await repository.getComparisonTraits()).single;
        await repository.setComparisonCheckin(
          traitId: trait['id'] as String,
          date: DateTime(2026, 11, 10),
          recorded: true,
        );

        await repository.deleteComparisonTrait(trait['id'] as String);

        expect(await repository.getComparisonTraits(), isEmpty);
        expect(
          await repository.getComparisonCheckins(trait['id'] as String),
          isEmpty,
        );
        expect((await repository.getHabitLogs(habitId)).length, 1);
      },
    );

    test(
      'backup v6 round-trips comparison data and v5 backups upgrade',
      () async {
        await repository.ensureComparisonSeeded();
        await repository.setComparisonCheckin(
          traitId: 'tpl_leitura',
          date: DateTime(2026, 11, 10),
          recorded: true,
        );
        final backup = await repository.exportBackup();
        expect(backup['version'], 6);

        final restored = AppDatabase.forTesting(NativeDatabase.memory());
        final restoredRepository = OrvaRepository(restored);
        try {
          final decoded =
              jsonDecode(jsonEncode(backup)) as Map<String, dynamic>;
          await restoredRepository.importBackup(decoded);
          expect((await restoredRepository.getComparisonTraits()).length, 4);
          expect(
            (await restoredRepository.getComparisonCheckins('tpl_leitura'))
                .length,
            1,
          );

          final legacyData =
              Map<String, dynamic>.from(decoded['data'] as Map<String, dynamic>)
                ..remove('comparison_profiles')
                ..remove('comparison_traits')
                ..remove('comparison_checkins');
          final legacy = <String, dynamic>{
            'format': 'orva_backup',
            'version': 5,
            'exportedAt': decoded['exportedAt'],
            'data': legacyData,
          };

          await restoredRepository.importBackup(legacy);
          expect(await restoredRepository.getComparisonTraits(), isEmpty);
          expect(
            await restoredRepository.getComparisonCheckins('tpl_leitura'),
            isEmpty,
          );
        } finally {
          await restored.close();
        }
      },
    );

    test(
      'upgrading a schema v5 database keeps rows and adds comparison tables',
      () async {
        final directory = await Directory.systemTemp.createTemp(
          'orva_migration',
        );
        final file = File('${directory.path}/orva.sqlite');
        try {
          final first = AppDatabase.forTesting(NativeDatabase(file));
          final firstRepository = OrvaRepository(first);
          await firstRepository.saveHabit(name: 'Leitura', unit: 'páginas');
          await first.customStatement('DROP TABLE comparison_checkins');
          await first.customStatement('DROP TABLE comparison_traits');
          await first.customStatement('DROP TABLE comparison_profiles');
          await first.customStatement('PRAGMA user_version = 5');
          await first.close();

          final second = AppDatabase.forTesting(NativeDatabase(file));
          final secondRepository = OrvaRepository(second);
          try {
            expect(
              (await secondRepository.getHabits()).single['name'],
              'Leitura',
            );
            await secondRepository.ensureComparisonSeeded();
            expect((await secondRepository.getComparisonTraits()).length, 4);
            expect((await secondRepository.getComparisonProfiles()).length, 2);
          } finally {
            await second.close();
          }
        } finally {
          await directory.delete(recursive: true);
        }
      },
    );
  });
}
