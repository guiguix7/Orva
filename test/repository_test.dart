import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orva/core/database/app_database.dart';
import 'package:orva/core/database/orva_repository.dart';

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
