import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orva/core/database/app_database.dart';
import 'package:orva/core/database/orva_repository.dart';
import 'package:orva/core/database/study_repository.dart';
import 'package:orva/core/database/nutrition_repository.dart';
import 'package:orva/core/database/obligations_repository.dart';

void main() {
  late AppDatabase database;
  late OrvaRepository repository;

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    repository = OrvaRepository(database);
  });

  tearDown(() async {
    await database.close();
  });

  test('PIN retry limits persist and reset after successful authentication', () async {
    await repository.setPin(pinHash: 'test-hash', pinSalt: 'test-salt');

    for (var attempt = 0; attempt < 4; attempt++) {
      expect(await repository.recordPinFailure(), isNull);
    }

    final before = DateTime.now();
    final lockout = await repository.recordPinFailure();
    expect(lockout, isNotNull);
    expect(lockout!.difference(before).inSeconds, inInclusiveRange(29, 30));
    expect(await repository.getPinFailedAttempts(), 5);
    expect(
      (await repository.getPinLockoutUntil())!.millisecondsSinceEpoch,
      lockout.millisecondsSinceEpoch,
    );

    await repository.resetPinFailures();
    expect(await repository.getPinFailedAttempts(), 0);
    expect(await repository.getPinLockoutUntil(), isNull);
  });

  test('disabling local lock clears PIN retry lockout state', () async {
    await repository.setPin(pinHash: 'test-hash', pinSalt: 'test-salt');
    for (var attempt = 0; attempt < 5; attempt++) {
      await repository.recordPinFailure();
    }

    await repository.disableLock();
    expect(await repository.isLockEnabled(), isFalse);
    expect(await repository.getPinHashAndSalt(), isNull);
    expect(await repository.getPinFailedAttempts(), 0);
    expect(await repository.getPinLockoutUntil(), isNull);
  });

  test('study subjects, topic hierarchy, sessions and reviews persist as real records', () async {
    await repository.saveGoal(title: 'Estudar Flutter', metricName: 'minutos', targetValue: 600, unit: 'min');
    final goal = (await repository.getGoals(status: 'active')).single;
    await repository.saveStudySubject(
      name: 'Programação',
      description: 'Aprendizado técnico',
      goalId: goal['id'] as String,
    );
    final subject = (await repository.getStudySubjects()).single;
    await repository.saveStudyTopic(subjectId: subject['id'] as String, name: 'Flutter');
    final topic = (await repository.getStudyTopics(subject['id'] as String)).single;
    await repository.saveStudyTopic(
      subjectId: subject['id'] as String,
      parentTopicId: topic['id'] as String,
      name: 'Riverpod',
    );
    await repository.saveStudySession(
      subjectId: subject['id'] as String,
      topicId: topic['id'] as String,
      goalId: goal['id'] as String,
      sessionDate: DateTime(2026, 10, 13),
      startMinute: 840,
      durationMinutes: 75,
      note: 'Providers e estado',
    );
    await repository.saveStudyReview(
      subjectId: subject['id'] as String,
      topicId: topic['id'] as String,
      reviewedAt: DateTime(2026, 10, 13),
      reviewKind: 'quiz',
      confidence: 4,
      note: 'Rever tratamento de erros',
    );

    final summary = await repository.getStudySummary(
      from: DateTime(2026, 10, 12),
      to: DateTime(2026, 10, 18),
    );
    expect(summary['sessions'], 1);
    expect(summary['minutes'], 75);
    expect(summary['studyDays'], 1);
    expect(summary['reviews'], 1);
    expect((await repository.getStudySessions()).single['goal_id'], goal['id']);
    expect((await repository.getStudyReviews()).single['confidence'], 4);
    expect((await repository.getStudySubjects()).single['total_minutes'], 75);
  });

  test('planned meal and consumed meal are separate; nutrition snapshots survive food edits', () async {
    await repository.saveFood(
      name: 'Aveia',
      referenceAmount: 100,
      referenceUnit: 'g',
      calories: 380,
      proteinG: 13,
      carbohydratesG: 68,
      nutritionSource: 'Rótulo informado pelo usuário',
    );
    final food = (await repository.getFoods()).single;
    await repository.saveMealPlan(
      title: 'Café planejado',
      mealType: 'breakfast',
      recurrence: 'weekly',
      weekdays: [2],
      startDate: '2026-10-13',
      plannedMinute: 480,
    );
    final plan = (await repository.getMealPlansForDate(DateTime(2026, 10, 13))).single;
    await repository.addMealPlanItem(
      mealPlanId: plan['id'] as String,
      foodId: food['id'] as String,
      quantity: 150,
    );
    expect((await repository.getMealPlanItems(plan['id'] as String)).single['calories'], 570);

    await repository.saveFoodConsumption(
      consumedDate: DateTime(2026, 10, 13),
      consumedMinute: 495,
      mealType: 'breakfast',
      title: 'Café consumido',
      items: [FoodQuantity(foodId: food['id'] as String, quantity: 150)],
    );
    final summary = await repository.getNutritionSummary(DateTime(2026, 10, 13));
    expect(summary['consumptionCount'], 1);
    expect(summary['itemCount'], 1);
    expect(summary['calories'], 570);
    expect(summary['isPartial'], isTrue);

    await repository.saveFood(
      id: food['id'] as String,
      name: 'Aveia atualizada',
      referenceAmount: 100,
      referenceUnit: 'g',
      calories: 100,
    );
    final consumption = (await repository.getFoodConsumptionsForDate(DateTime(2026, 10, 13))).single;
    final snapshot = (await repository.getFoodConsumptionItems(consumption['id'] as String)).single;
    expect(snapshot['food_name_snapshot'], 'Aveia');
    expect(snapshot['calories'], 570);
    expect((await repository.getMealPlansForDate(DateTime(2026, 10, 13))).length, 1);
  });

  test('overnight obligations split across dates and exceptions affect only one occurrence', () async {
    await repository.saveObligationRule(
      name: 'Sono',
      category: 'Descanso',
      startMinute: 22 * 60 + 30,
      endMinute: 7 * 60 + 30,
      recurrence: 'daily',
      startDate: DateTime(2026, 10, 12),
    );
    final nextDay = DateTime(2026, 10, 13);
    final blocks = await repository.getObligationTimeBlocksForDate(nextDay);
    expect(blocks, hasLength(2));
    expect(blocks.first['start_minute'], 0);
    expect(blocks.first['end_minute'], 450);
    expect(blocks.last['start_minute'], 1350);
    expect(blocks.last['end_minute'], 1440);
    final totalMinutes = blocks.fold<int>(
      0,
      (sum, block) => sum +
          (block['end_minute'] as num).toInt() -
          (block['start_minute'] as num).toInt(),
    );
    expect(totalMinutes, 540);

    final occurrences = await repository.getObligationOccurrencesForDate(nextDay);
    final currentOccurrence = occurrences.single;
    await repository.saveObligationException(
      ruleId: currentOccurrence['rule_id'] as String,
      occurrenceDate: nextDay,
      action: 'skip',
      note: 'Dia de descanso',
    );
    expect((await repository.getObligationOccurrencesForDate(nextDay)).single['status'], 'skipped');
    final afterException = await repository.getObligationTimeBlocksForDate(nextDay);
    expect(afterException.where((block) => block['obligation_date'] == '2026-10-13'), isEmpty);
    expect(afterException.where((block) => block['continues_from_previous_day'] == 1), hasLength(1));
    await repository.clearObligationException(currentOccurrence['rule_id'] as String, nextDay);
    expect((await repository.getObligationOccurrencesForDate(nextDay)).single['status'], 'planned');
  });

  test('version 3 backup imports with new modules empty and old local data intact', () async {
    await repository.saveNote(title: 'Backup antigo', content: 'Conteúdo preservado');
    final exported = await repository.exportBackup();
    final oldBackup = Map<String, dynamic>.from(exported);
    final data = Map<String, dynamic>.from(exported['data'] as Map);
    const newTables = [
      'study_subjects','study_topics','study_sessions','study_reviews',
      'foods','meal_plans','meal_plan_items','food_consumptions','food_consumption_items',
      'obligation_rules','obligation_exceptions','obligation_occurrences',
    ];
    for (final table in newTables) {
      data.remove(table);
    }
    oldBackup['version'] = 3;
    oldBackup['data'] = data;

    await repository.saveNote(title: 'Dados posteriores', content: 'Será substituído');
    await repository.importBackup(oldBackup);

    expect((await repository.getNotes()).single['title'], 'Backup antigo');
    expect(await repository.getStudySubjects(), isEmpty);
    expect(await repository.getFoods(), isEmpty);
    expect(await repository.getObligationRules(), isEmpty);
  });

  test('starts without goals, checklists, hobbies, notes or journal entries', () async {
    expect(await repository.getGoals(), isEmpty);
    expect(await repository.getChecklists(includeTemplates: true), isEmpty);
    expect(await repository.getHobbies(), isEmpty);
    expect(await repository.getNotes(), isEmpty);
    expect(await repository.getJournalEntries(), isEmpty);
  });

  test('recurring checklist occurrences are unique and preserve each date snapshot', () async {
    await repository.saveChecklist(title: 'Lista pessoal', recurrence: 'daily');
    final checklist = (await repository.getChecklists(includeTemplates: false)).single;
    final checklistId = checklist['id'] as String;
    await repository.addChecklistItem(checklistId: checklistId, title: 'Texto original');

    final firstDay = DateTime.now();
    final firstOccurrenceItems = await repository.getTodayOccurrenceItems(firstDay);
    expect(firstOccurrenceItems, hasLength(1));
    final firstItemId = firstOccurrenceItems.single['id'] as String;
    await repository.setOccurrenceItemCompleted(firstItemId, true);
    await repository.updateChecklistItem(firstOccurrenceItems.single['checklist_item_id'] as String, 'Texto atualizado');

    final firstDayAgain = await repository.getTodayOccurrenceItems(firstDay);
    expect(firstDayAgain.single['title_snapshot'], 'Texto original');
    expect(firstDayAgain.single['completed'], 1);
    final historicSnapshot = await repository.getOccurrenceSnapshotItems(checklistId, repository.dateKey(firstDay));
    expect(historicSnapshot, hasLength(1));
    expect(historicSnapshot.single['title_snapshot'], 'Texto original');
    expect(historicSnapshot.single['completed'], 1);

    final nextDay = firstDay.add(const Duration(days: 1));
    final nextOccurrenceItems = await repository.getTodayOccurrenceItems(nextDay);
    expect(nextOccurrenceItems, hasLength(1));
    expect(nextOccurrenceItems.single['title_snapshot'], 'Texto atualizado');
    expect(nextOccurrenceItems.single['completed'], 0);

    await repository.ensureOccurrences(nextDay);
    expect(await repository.getOccurrenceHistory(checklistId), hasLength(2));
  });

  test('concurrent reads do not duplicate an occurrence', () async {
    await repository.saveChecklist(title: 'Leitura simultânea', recurrence: 'daily');
    final checklist = (await repository.getChecklists(includeTemplates: false)).single;
    await repository.addChecklistItem(checklistId: checklist['id'] as String, title: 'Item');

    final reads = await Future.wait([
      repository.getTodayOccurrenceItems(),
      repository.getTodayOccurrenceItems(),
    ]);

    expect(reads[0], hasLength(1));
    expect(reads[1], hasLength(1));
    expect(await repository.getOccurrenceHistory(checklist['id'] as String), hasLength(1));
  });

  test('existing historical occurrences are not backfilled with later items', () async {
    await repository.saveChecklist(title: 'Histórico fixo', recurrence: 'daily');
    final checklist = (await repository.getChecklists(includeTemplates: false)).single;
    final checklistId = checklist['id'] as String;
    await repository.addChecklistItem(checklistId: checklistId, title: 'Item antigo');
    final originalItem = (await repository.getChecklistItems(checklistId)).single;

    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    final createdBeforeYesterday = yesterday.subtract(const Duration(days: 1)).toIso8601String();
    await repository.execute('UPDATE checklists SET created_at=? WHERE id=?', [createdBeforeYesterday, checklistId]);
    await repository.execute('UPDATE checklist_items SET created_at=? WHERE id=?', [createdBeforeYesterday, originalItem['id']]);
    await repository.getTodayOccurrenceItems(yesterday);

    await repository.addChecklistItem(checklistId: checklistId, title: 'Item criado depois');
    await repository.getTodayOccurrenceItems(yesterday);
    final snapshot = await repository.getOccurrenceSnapshotItems(checklistId, repository.dateKey(yesterday));

    expect(snapshot, hasLength(1));
    expect(snapshot.single['title_snapshot'], 'Item antigo');
  });

  test('backup export/import restores local data and removes records not in backup', () async {
    await repository.saveNote(title: 'Nota preservada', content: 'Conteúdo local');
    final backup = await repository.exportBackup();
    await repository.saveNote(title: 'Nota posterior', content: 'Não estará no backup anterior');

    await repository.importBackup(backup);
    final notes = await repository.getNotes();
    expect(notes, hasLength(1));
    expect(notes.single['title'], 'Nota preservada');
    expect(notes.single['content'], 'Conteúdo local');
  });

  test('invalid backups are rejected without changing existing local records', () async {
    await repository.saveNote(title: 'Não apagar', content: 'Registro local');

    await expectLater(
      repository.importBackup({'format': 'orva_backup', 'version': 2, 'data': <String, Object?>{}}),
      throwsFormatException,
    );

    final notes = await repository.getNotes();
    expect(notes, hasLength(1));
    expect(notes.single['title'], 'Não apagar');
  });

  test('routine weekly templates preserve date-specific exceptions when applied', () async {
    await repository.saveRoutineBlock(
      title: 'Bloco recorrente',
      category: 'Trabalho',
      startMinute: 540,
      endMinute: 600,
      blockKind: 'weekday',
      weekday: 1,
    );
    await repository.saveRoutineBlock(
      title: 'Compromisso pontual',
      category: 'Pessoal',
      startMinute: 720,
      endMinute: 780,
      blockKind: 'date',
      specificDate: '2026-10-12',
    );
    await repository.saveCurrentRoutineAsTemplate(name: 'Minha semana');
    final template = (await repository.getRoutineTemplates()).single;
    expect(template['block_count'], 1);

    await repository.saveRoutineBlock(
      title: 'Bloco temporário',
      category: '',
      startMinute: 600,
      endMinute: 660,
      blockKind: 'weekday',
      weekday: 1,
    );
    await repository.applyRoutineTemplate(template['id'] as String);

    final blocks = await repository.getRoutineForDate(DateTime(2026, 10, 12));
    expect(blocks.map((item) => item['title']), containsAll(['Bloco recorrente', 'Compromisso pontual']));
    expect(blocks.map((item) => item['title']), isNot(contains('Bloco temporário')));
    expect(blocks.firstWhere((item) => item['title'] == 'Bloco recorrente')['template_name'], 'Minha semana');
  });

  test('rejects routine blocks whose end is not after their start', () async {
    await expectLater(
      repository.saveRoutineBlock(
        title: 'Bloco inválido',
        category: '',
        startMinute: 600,
        endMinute: 600,
        blockKind: 'weekday',
        weekday: 1,
      ),
      throwsArgumentError,
    );
  });
}
