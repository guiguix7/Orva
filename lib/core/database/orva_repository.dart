import 'dart:convert';
import 'dart:math';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_database.dart';
import '../domain/orva_calculations.dart';
import '../logging/orva_diagnostics.dart';

final databaseProvider = Provider<AppDatabase>((ref) {
  final database = AppDatabase();
  ref.onDispose(database.close);
  return database;
});

final repositoryProvider = Provider<OrvaRepository>((ref) {
  return OrvaRepository(ref.watch(databaseProvider));
});

final databaseReadyProvider = FutureProvider<void>((ref) async {
  await ref.watch(databaseProvider).customSelect('SELECT 1').get();
});

final class OrvaRepository {
  OrvaRepository(this.db);

  final AppDatabase db;
  final Random _random = Random.secure();
  final Map<String, Future<void>> _occurrenceJobs = {};

  String newId() => '${DateTime.now().microsecondsSinceEpoch.toRadixString(16)}${_random.nextInt(0x7fffffff).toRadixString(16)}';
  String timestamp() => DateTime.now().toIso8601String();
  String dateKey(DateTime date) => '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  Future<List<Map<String, Object?>>> rows(
    String sql, [
    List<Variable<Object>> variables = const [],
  ]) async {
    try {
      final result = await db.customSelect(sql, variables: variables).get();
      return result.map((row) => Map<String, Object?>.from(row.data)).toList();
    } catch (error, stackTrace) {
      OrvaDiagnostics.instance.recordException(
        error,
        stackTrace,
        category: 'query',
        module: 'database',
      );
      rethrow;
    }
  }

  Future<void> execute(String sql, [List<Object?> args = const []]) async {
    try {
      await db.customStatement(sql, args);
    } catch (error, stackTrace) {
      OrvaDiagnostics.instance.recordException(
        error,
        stackTrace,
        category: 'statement',
        module: 'database',
      );
      rethrow;
    }
  }

  Future<String?> getSetting(String key) async {
    final result = await rows('SELECT setting_value FROM settings WHERE setting_key = ?', [Variable.withString(key)]);
    return result.isEmpty ? null : result.first['setting_value'] as String?;
  }

  Future<void> setSetting(String key, String value) async {
    await execute(
      '''INSERT INTO settings(setting_key, setting_value, updated_at) VALUES (?, ?, ?)
      ON CONFLICT(setting_key) DO UPDATE SET setting_value = excluded.setting_value, updated_at = excluded.updated_at''',
      [key, value, timestamp()],
    );
  }

  // User-defined category catalog. Records keep their category label as a
  // value so removing a catalog suggestion never erases historical records.
  Future<void> _rememberCategory(String? rawName, String scope) async {
    final name = rawName?.trim() ?? '';
    if (name.isEmpty) return;
    final existing = await rows('SELECT id FROM categories WHERE scope=? AND name=?', [Variable.withString(scope), Variable.withString(name)]);
    if (existing.isEmpty) {
      final now = timestamp();
      await execute('INSERT OR IGNORE INTO categories(id,name,scope,created_at,updated_at) VALUES(?,?,?,?,?)', [newId(), name, scope, now, now]);
    }
  }

  Future<List<Map<String, Object?>>> getCategories({String? scope}) {
    if (scope == null) return rows('SELECT * FROM categories ORDER BY scope, name COLLATE NOCASE');
    return rows('SELECT * FROM categories WHERE scope=? ORDER BY name COLLATE NOCASE', [Variable.withString(scope)]);
  }

  Future<void> saveCategory({String? id, required String name, required String scope}) async {
    if (name.trim().isEmpty) throw ArgumentError('Informe o nome da categoria.');
    final now = timestamp();
    if (id == null) {
      await execute('INSERT INTO categories(id,name,scope,created_at,updated_at) VALUES(?,?,?,?,?)', [newId(), name.trim(), scope, now, now]);
    } else {
      final oldRows = await rows('SELECT name,scope FROM categories WHERE id=?', [Variable.withString(id)]);
      if (oldRows.isEmpty) throw StateError('A categoria não existe mais.');
      final oldName = oldRows.first['name'] as String;
      final oldScope = oldRows.first['scope'] as String;
      await db.transaction(() async {
        await execute('UPDATE categories SET name=?,scope=?,updated_at=? WHERE id=?', [name.trim(), scope, now, id]);
        // Category labels are stored on records as values, not foreign keys.
        // Rename labels only when the category stays in the same module; moving
        // or removing a suggestion must not erase existing record labels.
        if (oldScope == scope) await _renameCategoryLabels(oldScope, oldName, name.trim());
      });
    }
  }

  Future<void> _renameCategoryLabels(String scope, String oldName, String newName) async {
    switch (scope) {
      case 'goals':
        await execute('UPDATE goals SET category=?, updated_at=? WHERE category=?', [newName.isEmpty ? null : newName, timestamp(), oldName]);
        break;
      case 'routine':
        await execute('UPDATE routine_blocks SET category=?, updated_at=? WHERE category=?', [newName, timestamp(), oldName]);
        break;
      case 'hobbies':
        await execute('UPDATE hobbies SET category=?, updated_at=? WHERE category=?', [newName.isEmpty ? null : newName, timestamp(), oldName]);
        break;
    }
  }

  Future<void> deleteCategory(String id) => execute('DELETE FROM categories WHERE id=?', [id]);

  // Goals ------------------------------------------------------------------
  Future<List<Map<String, Object?>>> getGoals({String? status}) async {
    if (status == null) return rows('SELECT * FROM goals ORDER BY updated_at DESC');
    return rows('SELECT * FROM goals WHERE status = ? ORDER BY deadline IS NULL, deadline, updated_at DESC', [Variable.withString(status)]);
  }

  Future<void> saveGoal({
    String? id,
    required String title,
    String description = '',
    String period = 'open',
    String? category,
    String? startDate,
    String? deadline,
    String? metricName,
    double? targetValue,
    String? unit,
    double progress = 0,
    String? parentId,
    String status = 'active',
  }) async {
    final now = timestamp();
    final recordId = id ?? newId();
    if (title.trim().isEmpty) throw ArgumentError('Informe um título para a meta.');
    if (!progress.isFinite || progress < 0 || progress > 100) throw ArgumentError('O progresso deve ser um número finito entre 0 e 100.');
    if (targetValue != null && (!targetValue.isFinite || targetValue < 0)) throw ArgumentError('O valor-alvo deve ser um número finito não negativo.' );
    if (parentId == recordId) throw ArgumentError('Uma meta não pode ser sua própria meta superior.');
    if (parentId != null) {
      final allGoals = await rows('SELECT id,parent_id FROM goals');
      final parents = {for (final item in allGoals) item['id'] as String: item['parent_id'] as String?};
      String ancestor = parentId;
      final visited = <String>{};
      while (visited.add(ancestor)) {
        if (ancestor == recordId) throw ArgumentError('Esse vínculo criaria um ciclo na hierarquia de metas.');
        final parent = parents[ancestor];
        if (parent == null) break;
        ancestor = parent;
      }
    }
    if (id == null) {
      await db.transaction(() async {
        await execute('''INSERT INTO goals(id,title,description,period,category,start_date,deadline,metric_name,target_value,unit,progress_value,progress_mode,parent_id,status,created_at,updated_at)
          VALUES(?,?,?,?,?,?,?,?,?,?,?,'manual',?,?,?,?)''', [recordId, title.trim(), description.trim(), period, _nullable(category), _nullable(startDate), _nullable(deadline), _nullable(metricName), targetValue, _nullable(unit), progress, _nullable(parentId), status, now, now]);
        await execute('INSERT INTO goal_progress_history(id,goal_id,progress_value,note,recorded_at) VALUES(?,?,?,?,?)', [newId(), recordId, progress, 'Valor inicial', now]);
      });
    } else {
      await db.transaction(() async {
        final old = await rows('SELECT progress_value FROM goals WHERE id = ?', [Variable.withString(recordId)]);
        await execute('''UPDATE goals SET title=?,description=?,period=?,category=?,start_date=?,deadline=?,metric_name=?,target_value=?,unit=?,progress_value=?,parent_id=?,status=?,updated_at=? WHERE id=?''', [title.trim(), description.trim(), period, _nullable(category), _nullable(startDate), _nullable(deadline), _nullable(metricName), targetValue, _nullable(unit), progress, _nullable(parentId), status, now, recordId]);
        if (old.isNotEmpty && (old.first['progress_value'] as num).toDouble() != progress) {
          await execute('INSERT INTO goal_progress_history(id,goal_id,progress_value,note,recorded_at) VALUES(?,?,?,?,?)', [newId(), recordId, progress, 'Atualização manual', now]);
        }
      });
    }
    await _rememberCategory(category, 'goals');
  }

  Future<void> setGoalStatus(String id, String status) async {
    const allowed = {'active', 'completed', 'archived'};
    if (!allowed.contains(status)) throw ArgumentError('Status de meta inválido.');
    await execute('UPDATE goals SET status=?, updated_at=? WHERE id=?', [status, timestamp(), id]);
  }

  Future<void> deleteGoal(String id) async {
    await db.transaction(() async {
      await execute('DELETE FROM goal_progress_history WHERE goal_id=?', [id]);
      // References from child goals are set to NULL; checklist and routine links
      // are also detached by their foreign-key policies.
      await execute('DELETE FROM goals WHERE id=?', [id]);
    });
  }

  Future<List<Map<String, Object?>>> getGoalHistory(String goalId) => rows(
        'SELECT * FROM goal_progress_history WHERE goal_id=? ORDER BY recorded_at DESC',
        [Variable.withString(goalId)],
      );

  // Checklists: definitions are separated from date-specific occurrences. --
  Future<List<Map<String, Object?>>> getChecklists({bool includeArchived = false, bool includeTemplates = true}) async {
    final clauses = <String>[];
    if (!includeArchived) clauses.add('is_active = 1');
    if (!includeTemplates) clauses.add('is_template = 0');
    final where = clauses.isEmpty ? '' : 'WHERE ${clauses.join(' AND ')}';
    return rows('SELECT * FROM checklists $where ORDER BY is_template, updated_at DESC');
  }

  Future<void> saveChecklist({
    String? id,
    required String title,
    String description = '',
    required String recurrence,
    List<int> weekdays = const [],
    String? scheduledDate,
    String? startDate,
    String? endDate,
    bool isTemplate = false,
  }) async {
    if (title.trim().isEmpty) throw ArgumentError('Informe um nome para o checklist.');
    if (recurrence == 'weekly' && weekdays.isEmpty && !isTemplate) {
      throw ArgumentError('Selecione ao menos um dia da semana.');
    }
    if (recurrence == 'once' && scheduledDate == null && !isTemplate) {
      throw ArgumentError('Selecione a data deste checklist.');
    }
    final now = timestamp();
    if (id == null) {
      await execute('''INSERT INTO checklists(id,title,description,recurrence,weekdays_json,scheduled_date,start_date,end_date,is_template,is_active,created_at,updated_at)
      VALUES(?,?,?,?,?,?,?,?,?,1,?,?)''', [newId(), title.trim(), description.trim(), recurrence, jsonEncode(weekdays.toSet().toList()..sort()), _nullable(scheduledDate), _nullable(startDate), _nullable(endDate), isTemplate ? 1 : 0, now, now]);
    } else {
      await execute('''UPDATE checklists SET title=?,description=?,recurrence=?,weekdays_json=?,scheduled_date=?,start_date=?,end_date=?,is_template=?,updated_at=? WHERE id=?''', [title.trim(), description.trim(), recurrence, jsonEncode(weekdays.toSet().toList()..sort()), _nullable(scheduledDate), _nullable(startDate), _nullable(endDate), isTemplate ? 1 : 0, now, id]);
    }
  }

  Future<void> archiveChecklist(String id) => execute('UPDATE checklists SET is_active=0, updated_at=? WHERE id=?', [timestamp(), id]);

  Future<void> restoreChecklist(String id) => execute('UPDATE checklists SET is_active=1, updated_at=? WHERE id=?', [timestamp(), id]);

  Future<void> deleteChecklist(String id) async {
    await db.transaction(() async {
      await execute('DELETE FROM checklist_occurrence_items WHERE occurrence_id IN (SELECT id FROM checklist_occurrences WHERE checklist_id=?)', [id]);
      await execute('DELETE FROM checklist_occurrences WHERE checklist_id=?', [id]);
      await execute('DELETE FROM checklist_items WHERE checklist_id=?', [id]);
      await execute('DELETE FROM checklists WHERE id=?', [id]);
    });
  }

  Future<List<Map<String, Object?>>> getChecklistItems(String checklistId) => rows(
        'SELECT * FROM checklist_items WHERE checklist_id=? AND is_active=1 ORDER BY order_index, created_at',
        [Variable.withString(checklistId)],
      );

  Future<void> addChecklistItem({required String checklistId, required String title, String? goalId}) async {
    if (title.trim().isEmpty) throw ArgumentError('O item não pode ficar vazio.');
    final current = await rows('SELECT COALESCE(MAX(order_index), -1) AS max_order FROM checklist_items WHERE checklist_id=?', [Variable.withString(checklistId)]);
    final nextOrder = ((current.first['max_order'] as num?)?.toInt() ?? -1) + 1;
    final id = newId();
    final now = timestamp();
    await db.transaction(() async {
      await execute('INSERT INTO checklist_items(id,checklist_id,title,order_index,goal_id,is_active,created_at,updated_at) VALUES(?,?,?,?,?,1,?,?)', [id, checklistId, title.trim(), nextOrder, _nullable(goalId), now, now]);
      // If this checklist already has an occurrence today, add the new item to
      // today's snapshot without changing any previous completed snapshots.
      final today = dateKey(DateTime.now());
      final occurrence = await rows('SELECT id FROM checklist_occurrences WHERE checklist_id=? AND reference_date=?', [Variable.withString(checklistId), Variable.withString(today)]);
      if (occurrence.isNotEmpty) {
        await execute('INSERT OR IGNORE INTO checklist_occurrence_items(id,occurrence_id,checklist_item_id,title_snapshot,order_snapshot,completed) VALUES(?,?,?,?,?,0)', [newId(), occurrence.first['id'], id, title.trim(), nextOrder]);
      }
    });
  }

  Future<void> archiveChecklistItem(String id) async {
    // Keep the definition row because occurrence snapshots may still reference it.
    await execute('UPDATE checklist_items SET is_active=0, updated_at=? WHERE id=?', [timestamp(), id]);
  }

  Future<void> updateChecklistItem(String id, String title) async {
    if (title.trim().isEmpty) throw ArgumentError('O item não pode ficar vazio.');
    await execute('UPDATE checklist_items SET title=?, updated_at=? WHERE id=?', [title.trim(), timestamp(), id]);
    // Occurrence title_snapshot values intentionally remain unchanged to protect history.
  }

  Future<void> reorderChecklistItems(List<String> orderedIds) async {
    await db.transaction(() async {
      for (var i = 0; i < orderedIds.length; i++) {
        await execute('UPDATE checklist_items SET order_index=?, updated_at=? WHERE id=?', [i, timestamp(), orderedIds[i]]);
      }
    });
  }

  bool _appliesToDate(Map<String, Object?> checklist, DateTime date) {
    final day = dateKey(date);
    final start = checklist['start_date'] as String?;
    final end = checklist['end_date'] as String?;
    final createdAt = checklist['created_at'] as String?;
    if (start != null && day.compareTo(start) < 0) return false;
    if (end != null && day.compareTo(end) > 0) return false;
    // A recurring definition cannot have occurrences before it existed. A
    // one-off checklist may intentionally be created for a past date.
    if (checklist['recurrence'] != 'once' && createdAt != null && day.compareTo(createdAt.substring(0, 10)) < 0) return false;
    switch (checklist['recurrence']) {
      case 'once':
        return checklist['scheduled_date'] == day;
      case 'daily':
        return true;
      case 'weekly':
        final raw = jsonDecode((checklist['weekdays_json'] as String?) ?? '[]') as List<dynamic>;
        // Dart weekday: Monday = 1 ... Sunday = 7.
        return raw.map((value) => (value as num).toInt()).contains(date.weekday);
      default:
        return false;
    }
  }

  Future<void> ensureOccurrences([DateTime? date]) {
    final target = date ?? DateTime.now();
    final key = dateKey(target);
    final inFlight = _occurrenceJobs[key];
    if (inFlight != null) return inFlight;

    late final Future<void> job;
    job = _ensureOccurrencesForDate(target, key).whenComplete(() {
      if (identical(_occurrenceJobs[key], job)) _occurrenceJobs.remove(key);
    });
    _occurrenceJobs[key] = job;
    return job;
  }

  Future<void> _ensureOccurrencesForDate(DateTime target, String key) async {
    await db.transaction(() async {
      final definitions = await rows('SELECT * FROM checklists WHERE is_active=1 AND is_template=0');
      for (final checklist in definitions) {
        if (!_appliesToDate(checklist, target)) continue;
        final checklistId = checklist['id'] as String;
        final existing = await rows(
          'SELECT id FROM checklist_occurrences WHERE checklist_id=? AND reference_date=?',
          [Variable.withString(checklistId), Variable.withString(key)],
        );
        // Existing occurrences are immutable snapshots: do not backfill them
        // with definitions added or edited after that day's occurrence existed.
        if (existing.isNotEmpty) continue;
        await execute(
          'INSERT OR IGNORE INTO checklist_occurrences(id,checklist_id,reference_date,created_at) VALUES(?,?,?,?)',
          [newId(), checklistId, key, timestamp()],
        );
        final occurrence = await rows(
          'SELECT id FROM checklist_occurrences WHERE checklist_id=? AND reference_date=?',
          [Variable.withString(checklistId), Variable.withString(key)],
        );
        if (occurrence.isEmpty) continue;
        final occurrenceId = occurrence.first['id'] as String;
        final items = await getChecklistItems(checklistId);
        for (final item in items) {
          final itemCreatedAt = item['created_at'] as String?;
          if (checklist['recurrence'] != 'once' && itemCreatedAt != null && key.compareTo(itemCreatedAt.substring(0, 10)) < 0) continue;
          await execute(
            'INSERT OR IGNORE INTO checklist_occurrence_items(id,occurrence_id,checklist_item_id,title_snapshot,order_snapshot,completed) VALUES(?,?,?,?,?,0)',
            [newId(), occurrenceId, item['id'], item['title'], item['order_index']],
          );
        }
      }
    });
  }

  Future<List<Map<String, Object?>>> getTodayOccurrenceItems([DateTime? date]) async {
    final key = dateKey(date ?? DateTime.now());
    await ensureOccurrences(date);
    return rows('''SELECT oi.*, o.checklist_id, o.reference_date, c.title AS checklist_title
      FROM checklist_occurrence_items oi
      JOIN checklist_occurrences o ON o.id=oi.occurrence_id
      JOIN checklists c ON c.id=o.checklist_id
      WHERE o.reference_date=? AND c.is_active=1
      ORDER BY c.updated_at DESC, oi.order_snapshot''', [Variable.withString(key)]);
  }

  Future<List<Map<String, Object?>>> getOccurrenceHistory(String checklistId) => rows('''SELECT o.reference_date,
      COUNT(oi.id) AS total, SUM(oi.completed) AS completed
      FROM checklist_occurrences o LEFT JOIN checklist_occurrence_items oi ON oi.occurrence_id=o.id
      WHERE o.checklist_id=? GROUP BY o.id ORDER BY o.reference_date DESC''', [Variable.withString(checklistId)]);

  Future<List<Map<String, Object?>>> getOccurrenceSnapshotItems(String checklistId, String referenceDate) => rows('''
      SELECT oi.title_snapshot, oi.order_snapshot, oi.completed, oi.completed_at
      FROM checklist_occurrences o
      JOIN checklist_occurrence_items oi ON oi.occurrence_id=o.id
      WHERE o.checklist_id=? AND o.reference_date=?
      ORDER BY oi.order_snapshot
    ''', [Variable.withString(checklistId), Variable.withString(referenceDate)]);

  Future<void> setOccurrenceItemCompleted(String id, bool completed) => execute(
        'UPDATE checklist_occurrence_items SET completed=?, completed_at=? WHERE id=?',
        [completed ? 1 : 0, completed ? timestamp() : null, id],
      );

  // Routine ----------------------------------------------------------------
  Future<List<Map<String, Object?>>> getRoutineForDate([DateTime? date]) {
    final target = date ?? DateTime.now();
    final weekday = target.weekday;
    final key = dateKey(target);
    return rows('''SELECT rb.*, g.title AS goal_title, h.name AS hobby_name FROM routine_blocks rb
      LEFT JOIN goals g ON g.id=rb.goal_id LEFT JOIN hobbies h ON h.id=rb.hobby_id
      WHERE (rb.block_kind='weekday' AND rb.weekday=?) OR (rb.block_kind='date' AND rb.specific_date=?)
      ORDER BY rb.start_minute''', [Variable.withInt(weekday), Variable.withString(key)]);
  }

  Future<List<Map<String, Object?>>> getRoutineBlocks() => rows('''SELECT rb.*, g.title AS goal_title, h.name AS hobby_name FROM routine_blocks rb
    LEFT JOIN goals g ON g.id=rb.goal_id LEFT JOIN hobbies h ON h.id=rb.hobby_id ORDER BY rb.start_minute''');

  Future<void> saveRoutineBlock({
    String? id,
    required String title,
    required String category,
    required int startMinute,
    required int endMinute,
    required String blockKind,
    int? weekday,
    String? specificDate,
    String? templateName,
    String? goalId,
    String? hobbyId,
  }) async {
    if (title.trim().isEmpty) throw ArgumentError('Informe o nome da atividade.');
    if (startMinute < 0 || startMinute >= 1440 || endMinute > 1440 || endMinute <= startMinute) {
      throw ArgumentError('O horário final deve ser posterior ao inicial.');
    }
    if (blockKind == 'weekday' && weekday == null) throw ArgumentError('Selecione o dia da semana.');
    if (blockKind == 'date' && specificDate == null) throw ArgumentError('Selecione uma data.');
    final now = timestamp();
    if (id == null) {
      await execute('''INSERT INTO routine_blocks(id,title,category,start_minute,end_minute,block_kind,weekday,specific_date,template_name,goal_id,hobby_id,created_at,updated_at)
      VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?)''', [newId(), title.trim(), category.trim(), startMinute, endMinute, blockKind, weekday, _nullable(specificDate), _nullable(templateName), _nullable(goalId), _nullable(hobbyId), now, now]);
    } else {
      await execute('''UPDATE routine_blocks SET title=?,category=?,start_minute=?,end_minute=?,block_kind=?,weekday=?,specific_date=?,template_name=?,goal_id=?,hobby_id=?,updated_at=? WHERE id=?''', [title.trim(), category.trim(), startMinute, endMinute, blockKind, weekday, _nullable(specificDate), _nullable(templateName), _nullable(goalId), _nullable(hobbyId), now, id]);
    }
    await _rememberCategory(category, 'routine');
  }

  Future<void> deleteRoutineBlock(String id) => execute('DELETE FROM routine_blocks WHERE id=?', [id]);

  // Weekly routine templates are snapshots of recurring (weekday) blocks.
  // Applying one explicitly replaces only recurring blocks; date-specific
  // exceptions remain unchanged.
  Future<List<Map<String, Object?>>> getRoutineTemplates() => rows('''
    SELECT rt.*, COUNT(rtb.id) AS block_count
    FROM routine_templates rt
    LEFT JOIN routine_template_blocks rtb ON rtb.template_id=rt.id
    GROUP BY rt.id
    ORDER BY rt.name COLLATE NOCASE
  ''');

  Future<void> saveCurrentRoutineAsTemplate({required String name, String description = ''}) async {
    if (name.trim().isEmpty) throw ArgumentError('Informe um nome para o modelo semanal.');
    final weeklyBlocks = (await getRoutineBlocks()).where((block) => block['block_kind'] == 'weekday').toList();
    if (weeklyBlocks.isEmpty) throw StateError('Crie ao menos um bloco recorrente antes de salvar um modelo semanal.');
    final duplicate = await rows('SELECT id FROM routine_templates WHERE name=?', [Variable.withString(name.trim())]);
    if (duplicate.isNotEmpty) throw ArgumentError('Já existe um modelo semanal com esse nome.');

    final now = timestamp();
    final templateId = newId();
    await db.transaction(() async {
      await execute('INSERT INTO routine_templates(id,name,description,created_at,updated_at) VALUES(?,?,?,?,?)', [templateId, name.trim(), description.trim(), now, now]);
      for (var index = 0; index < weeklyBlocks.length; index++) {
        final block = weeklyBlocks[index];
        await execute('''INSERT INTO routine_template_blocks(id,template_id,title,category,start_minute,end_minute,weekday,goal_id,hobby_id,order_index)
          VALUES(?,?,?,?,?,?,?,?,?,?)''', [
          newId(), templateId, block['title'], block['category'] ?? '', block['start_minute'], block['end_minute'], block['weekday'], block['goal_id'], block['hobby_id'], index,
        ]);
      }
    });
  }

  Future<void> applyRoutineTemplate(String templateId) async {
    final templates = await rows('SELECT name FROM routine_templates WHERE id=?', [Variable.withString(templateId)]);
    if (templates.isEmpty) throw StateError('O modelo semanal não existe mais.');
    final name = templates.first['name'] as String;
    final blocks = await rows('SELECT * FROM routine_template_blocks WHERE template_id=? ORDER BY weekday,start_minute,order_index', [Variable.withString(templateId)]);
    if (blocks.isEmpty) throw StateError('Este modelo semanal não contém blocos.');
    await db.transaction(() async {
      await execute("DELETE FROM routine_blocks WHERE block_kind='weekday'");
      for (final block in blocks) {
        await execute('''INSERT INTO routine_blocks(id,title,category,start_minute,end_minute,block_kind,weekday,specific_date,template_name,goal_id,hobby_id,created_at,updated_at)
          VALUES(?,?,?,?,?,'weekday',?,NULL,?,?,?, ?,?)''', [
          newId(), block['title'], block['category'] ?? '', block['start_minute'], block['end_minute'], block['weekday'], name, block['goal_id'], block['hobby_id'], timestamp(), timestamp(),
        ]);
      }
    });
  }

  Future<void> deleteRoutineTemplate(String id) => execute('DELETE FROM routine_templates WHERE id=?', [id]);

  // Hobbies ----------------------------------------------------------------
  Future<List<Map<String, Object?>>> getHobbies({bool includeArchived = false}) => rows(
        'SELECT * FROM hobbies ${includeArchived ? '' : 'WHERE is_active=1'} ORDER BY name COLLATE NOCASE',
      );

  Future<void> saveHobby({String? id, required String name, String description = '', String? category, int? weeklyTargetMinutes}) async {
    if (name.trim().isEmpty) throw ArgumentError('Informe o nome do hobby.');
    if (weeklyTargetMinutes != null && weeklyTargetMinutes < 0) throw ArgumentError('A meta de tempo não pode ser negativa.');
    final now = timestamp();
    if (id == null) {
      await execute('INSERT INTO hobbies(id,name,description,category,weekly_target_minutes,is_active,created_at,updated_at) VALUES(?,?,?,?,?,1,?,?)', [newId(), name.trim(), description.trim(), _nullable(category), weeklyTargetMinutes, now, now]);
    } else {
      await execute('UPDATE hobbies SET name=?,description=?,category=?,weekly_target_minutes=?,updated_at=? WHERE id=?', [name.trim(), description.trim(), _nullable(category), weeklyTargetMinutes, now, id]);
    }
    await _rememberCategory(category, 'hobbies');
  }

  Future<void> archiveHobby(String id) => execute('UPDATE hobbies SET is_active=0, updated_at=? WHERE id=?', [timestamp(), id]);

  Future<void> setHobbyActive(String id, bool active) => execute('UPDATE hobbies SET is_active=?, updated_at=? WHERE id=?', [active ? 1 : 0, timestamp(), id]);

  Future<void> deleteHobby(String id) async {
    await db.transaction(() async {
      await execute('DELETE FROM hobby_sessions WHERE hobby_id=?', [id]);
      await execute('DELETE FROM hobbies WHERE id=?', [id]);
    });
  }

  Future<void> addHobbySession({String? id, required String hobbyId, required String sessionDate, required int durationMinutes, int? startMinute, int? endMinute, String note = ''}) async {
    if (durationMinutes <= 0) throw ArgumentError('A duração deve ser maior que zero.');
    if (startMinute != null && endMinute != null && endMinute <= startMinute) throw ArgumentError('O horário final deve ser posterior ao inicial.');
    if (id == null) {
      await execute('INSERT INTO hobby_sessions(id,hobby_id,session_date,duration_minutes,start_minute,end_minute,note,created_at) VALUES(?,?,?,?,?,?,?,?)', [newId(), hobbyId, sessionDate, durationMinutes, startMinute, endMinute, note.trim(), timestamp()]);
    } else {
      await execute('UPDATE hobby_sessions SET hobby_id=?,session_date=?,duration_minutes=?,start_minute=?,end_minute=?,note=? WHERE id=?', [hobbyId, sessionDate, durationMinutes, startMinute, endMinute, note.trim(), id]);
    }
  }

  Future<List<Map<String, Object?>>> getHobbySessions(String hobbyId) => rows('SELECT * FROM hobby_sessions WHERE hobby_id=? ORDER BY session_date DESC, created_at DESC', [Variable.withString(hobbyId)]);

  Future<List<Map<String, Object?>>> getWeeklyHobbyMinutes({DateTime? date, bool includeArchived = false}) async {
    final target = date ?? DateTime.now();
    final monday = DateTime(target.year, target.month, target.day).subtract(Duration(days: target.weekday - 1));
    final sunday = monday.add(const Duration(days: 6));
    return rows('''SELECT h.id, h.name, h.is_active, h.weekly_target_minutes,
      COALESCE(SUM(CASE WHEN hs.session_date BETWEEN ? AND ? THEN hs.duration_minutes ELSE 0 END),0) AS actual_minutes
      FROM hobbies h LEFT JOIN hobby_sessions hs ON hs.hobby_id=h.id
      WHERE ${includeArchived ? '1=1' : 'h.is_active=1'} GROUP BY h.id ORDER BY h.name COLLATE NOCASE''', [Variable.withString(dateKey(monday)), Variable.withString(dateKey(sunday))]);
  }

  Future<void> deleteHobbySession(String id) => execute('DELETE FROM hobby_sessions WHERE id=?', [id]);

  // Notes ------------------------------------------------------------------
  Future<List<Map<String, Object?>>> getNotes({String search = ''}) {
    if (search.trim().isEmpty) return rows('SELECT * FROM notes ORDER BY updated_at DESC');
    final term = '%${search.trim()}%';
    return rows('SELECT * FROM notes WHERE title LIKE ? OR content LIKE ? ORDER BY updated_at DESC', [Variable.withString(term), Variable.withString(term)]);
  }

  Future<void> saveNote({String? id, required String title, required String content, List<String> tags = const []}) async {
    if (title.trim().isEmpty && content.trim().isEmpty) throw ArgumentError('Escreva um título ou conteúdo para a nota.');
    final now = timestamp();
    if (id == null) {
      await execute('INSERT INTO notes(id,title,content,tags_json,created_at,updated_at) VALUES(?,?,?,?,?,?)', [newId(), title.trim(), content, jsonEncode(tags), now, now]);
    } else {
      await execute('UPDATE notes SET title=?,content=?,tags_json=?,updated_at=? WHERE id=?', [title.trim(), content, jsonEncode(tags), now, id]);
    }
  }

  Future<void> deleteNote(String id) => execute('DELETE FROM notes WHERE id=?', [id]);

  // Journal ----------------------------------------------------------------
  Future<List<Map<String, Object?>>> getJournalEntries({String search = ''}) {
    if (search.trim().isEmpty) return rows('SELECT * FROM journal_entries ORDER BY entry_date DESC');
    final term = '%${search.trim()}%';
    return rows('SELECT * FROM journal_entries WHERE content LIKE ? OR mood LIKE ? OR tags_json LIKE ? ORDER BY entry_date DESC', [Variable.withString(term), Variable.withString(term), Variable.withString(term)]);
  }

  Future<Map<String, Object?>?> getJournalEntryForDate(DateTime date) async {
    final result = await rows('SELECT * FROM journal_entries WHERE entry_date=?', [Variable.withString(dateKey(date))]);
    return result.isEmpty ? null : result.first;
  }

  Future<void> saveJournalEntry({String? id, required String entryDate, required String content, String? mood, List<String> tags = const []}) async {
    if (content.trim().isEmpty) throw ArgumentError('Escreva algo antes de salvar a entrada.');
    final now = timestamp();
    final existing = await getJournalEntryForDate(DateTime.parse(entryDate));
    if (existing != null) {
      final existingId = existing['id'] as String;
      await execute('UPDATE journal_entries SET content=?,mood=?,tags_json=?,updated_at=? WHERE id=?', [content, _nullable(mood), jsonEncode(tags), now, existingId]);
    } else {
      await execute('INSERT INTO journal_entries(id,entry_date,content,mood,tags_json,created_at,updated_at) VALUES(?,?,?,?,?,?,?)', [id ?? newId(), entryDate, content, _nullable(mood), jsonEncode(tags), now, now]);
    }
  }

  Future<void> deleteJournalEntry(String id) => execute('DELETE FROM journal_entries WHERE id=?', [id]);

  // Dashboard calculations are all derived from actual local records. ------
  Future<Map<String, Object?>> getTodaySummary([DateTime? date]) async {
    final target = date ?? DateTime.now();
    final goals = await rows("SELECT COUNT(*) AS count FROM goals WHERE status='active'");
    final todayItems = await getTodayOccurrenceItems(target);
    final total = todayItems.length;
    final completed = todayItems.where((item) => (item['completed'] as num).toInt() == 1).length;
    final routine = await getRoutineForDate(target);
    final intervals = routine.map((block) => PlannedInterval(
      (block['start_minute'] as num).toInt(), (block['end_minute'] as num).toInt(),
      (block['category'] as String?)?.trim().isNotEmpty == true ? block['category'] as String : 'Sem categoria',
      block['title'] as String,
    )).toList();
    final plannedMinutes = occupiedMinutes(intervals);
    final categoryTotals = categoryMinutes(intervals);
    return {
      'activeGoals': (goals.first['count'] as num).toInt(),
      'checklistTotal': total,
      'checklistCompleted': completed,
      'checklistProgress': total == 0 ? null : completed / total,
      'routineBlocks': routine.length,
      'plannedMinutes': plannedMinutes,
      'unplannedMinutes': 1440 - plannedMinutes,
      'plannedCategories': categoryTotals,
    };
  }

  // ===========================================================================
  // Perfil do usuário (local). Guardado como pares chave/valor na tabela
  // settings existente — não exige migração de esquema própria. Datas são
  // ISO 8601 (AAAA-MM-DD). Nenhum campo é obrigatório para o app funcionar.
  // ===========================================================================
  static const _profileKeys = <String>[
    'profile_name',
    'profile_birth_date',
    'profile_height_cm',
    'profile_gender',
  ];

  Future<Map<String, String?>> getProfile() async {
    final values = await Future.wait(_profileKeys.map(getSetting));
    return Map.fromIterables(_profileKeys, values);
  }

  Future<void> saveProfile({
    String? name,
    String? birthDateIso,
    double? heightCm,
    String? gender,
  }) async {
    await setSetting('profile_name', name?.trim() ?? '');
    await setSetting('profile_birth_date', birthDateIso ?? '');
    await setSetting('profile_height_cm', heightCm == null ? '' : heightCm.toString());
    await setSetting('profile_gender', gender ?? '');
  }

  /// Idade em anos completos na data de referência (padrão: hoje). Retorna
  /// null quando a data de nascimento não foi informada.
  int? ageInYears(DateTime birthDate, [DateTime? reference]) {
    final now = reference ?? DateTime.now();
    var age = now.year - birthDate.year;
    if (now.month < birthDate.month || (now.month == birthDate.month && now.day < birthDate.day)) {
      age -= 1;
    }
    return age;
  }

  // ===========================================================================
  // Histórico de peso. Cada chamada cria um novo registro datado; medições
  // anteriores nunca são apagadas ou sobrescritas ao registrar um novo peso.
  // ===========================================================================
  Future<List<Map<String, Object?>>> getWeightEntries() =>
      rows('SELECT * FROM weight_entries ORDER BY measured_at DESC, created_at DESC');

  Future<void> saveWeightEntry({required DateTime measuredAt, required double weightKg, String note = ''}) async {
    if (weightKg <= 0) throw ArgumentError('Informe um peso maior que zero.');
    await execute(
      'INSERT INTO weight_entries(id, measured_at, weight_kg, note, created_at) VALUES(?,?,?,?,?)',
      [newId(), dateKey(measuredAt), weightKg, note.trim(), timestamp()],
    );
  }

  Future<void> deleteWeightEntry(String id) => execute('DELETE FROM weight_entries WHERE id = ?', [id]);

  /// IMC para adultos (kg / m²). O chamador deve evitar classificar o
  /// resultado como diagnóstico e deve usar critérios diferentes (não
  /// implementados aqui) para menores de 20 anos.
  double bodyMassIndex({required double weightKg, required double heightCm}) {
    final heightM = heightCm / 100;
    if (heightM <= 0) throw ArgumentError('Altura inválida.');
    return weightKg / (heightM * heightM);
  }

  // ===========================================================================
  // Bloqueio local (PIN). O PIN nunca é guardado em texto puro: apenas um
  // hash salgado (ver core/security/pin_security.dart). Chaves de segurança
  // começam com "security_" e são deliberadamente excluídas do backup JSON
  // (ver _backupTables/exportBackup/importBackup abaixo).
  // ===========================================================================
  Future<bool> isLockEnabled() async => (await getSetting('security_lock_enabled')) == '1';

  Future<bool> hasPinConfigured() async => (await getSetting('security_pin_hash'))?.isNotEmpty == true;

  Future<bool> isBiometricEnabled() async => (await getSetting('security_biometric_enabled')) == '1';

  Future<void> setBiometricEnabled(bool enabled) => setSetting('security_biometric_enabled', enabled ? '1' : '0');

  Future<void> setPin({required String pinHash, required String pinSalt}) async {
    // PIN hash, salt and enabled state must change atomically. A partially
    // written setting must never leave the app believing a PIN is configured.
    await db.transaction(() async {
      await _writeSettingsAtomically({
        'security_pin_hash': pinHash,
        'security_pin_salt': pinSalt,
        'security_lock_enabled': '1',
        'security_pin_failed_attempts': '0',
        'security_pin_lockout_until': '0',
      });
    });
  }

  Future<void> disableLock() async {
    await db.transaction(() async {
      await _writeSettingsAtomically({
        'security_lock_enabled': '0',
        'security_pin_hash': '',
        'security_pin_salt': '',
        'security_biometric_enabled': '0',
        'security_pin_failed_attempts': '0',
        'security_pin_lockout_until': '0',
      });
    });
  }

  Future<({String hash, String salt})?> getPinHashAndSalt() async {
    final hash = await getSetting('security_pin_hash');
    final salt = await getSetting('security_pin_salt');
    if (hash == null || salt == null || hash.isEmpty || salt.isEmpty) return null;
    return (hash: hash, salt: salt);
  }

  Future<void> _writeSettingsAtomically(Map<String, String> values) async {
    final now = timestamp();
    for (final entry in values.entries) {
      await execute(
        '''INSERT INTO settings(setting_key, setting_value, updated_at)
        VALUES (?, ?, ?)
        ON CONFLICT(setting_key) DO UPDATE SET
          setting_value=excluded.setting_value, updated_at=excluded.updated_at''',
        [entry.key, entry.value, now],
      );
    }
  }

  Future<int> getPinFailedAttempts() async =>
      int.tryParse(await getSetting('security_pin_failed_attempts') ?? '') ?? 0;

  Future<DateTime?> getPinLockoutUntil() async {
    final milliseconds =
        int.tryParse(await getSetting('security_pin_lockout_until') ?? '') ?? 0;
    if (milliseconds <= 0) return null;
    return DateTime.fromMillisecondsSinceEpoch(milliseconds);
  }

  /// Records a wrong PIN and applies an exponential pause from the fifth
  /// failure onward. Values persist locally so restarting the app cannot
  /// immediately reset the retry counter.
  Future<DateTime?> recordPinFailure() async {
    DateTime? lockoutUntil;
    await db.transaction(() async {
      final attempts = (int.tryParse(
                await getSetting('security_pin_failed_attempts') ?? '',
              ) ??
              0) +
          1;
      final values = <String, String>{
        'security_pin_failed_attempts': attempts.toString(),
      };
      if (attempts >= 5) {
        final exponent = (attempts - 5).clamp(0, 5).toInt();
        final seconds = (30 * (1 << exponent)).clamp(30, 900).toInt();
        lockoutUntil = DateTime.now().add(Duration(seconds: seconds));
        values['security_pin_lockout_until'] =
            lockoutUntil!.millisecondsSinceEpoch.toString();
      }
      await _writeSettingsAtomically(values);
    });
    return lockoutUntil;
  }

  Future<void> resetPinFailures() async {
    await db.transaction(() async {
      await _writeSettingsAtomically({
        'security_pin_failed_attempts': '0',
        'security_pin_lockout_until': '0',
      });
    });
  }

  // Backup format is explicit and versioned. Import callers must confirm data
  // replacement with the user before calling importBackup.
  static const backupVersion = 3;
  static const _backupTables = <String>[
    'categories',
    'goals',
    'goal_progress_history',
    'checklists',
    'checklist_items',
    'checklist_occurrences',
    'checklist_occurrence_items',
    'routine_blocks',
    'hobbies',
    'routine_templates',
    'routine_template_blocks',
    'hobby_sessions',
    'notes',
    'journal_entries',
    'weight_entries',
    'settings',
  ];

  /// Chaves de settings nunca incluídas no backup: PIN e flags de segurança.
  /// Perfil (nome, data de nascimento, altura, gênero) É incluído, pois são
  /// dados pessoais e não segredos de autenticação.
  static const _settingsKeysExcludedFromBackup = <String>{
    'security_pin_hash',
    'security_pin_salt',
    'security_lock_enabled',
    'security_biometric_enabled',
  };

  Future<Map<String, Object?>> exportBackup() async {
    final data = <String, Object?>{};
    for (final table in _backupTables) {
      if (table == 'settings') {
        final settingsRows = await rows('SELECT * FROM settings');
        data[table] = settingsRows.where((row) => !_settingsKeysExcludedFromBackup.contains(row['setting_key'])).toList();
      } else {
        data[table] = await rows('SELECT * FROM $table');
      }
    }
    return {
      'format': 'orva_backup',
      'version': backupVersion,
      'exportedAt': timestamp(),
      'data': data,
    };
  }

  Future<void> importBackup(Object? decoded) async {
    if (decoded is! Map<String, dynamic> || decoded['format'] != 'orva_backup') {
      throw const FormatException('Este arquivo não é um backup válido do Orva.');
    }
    if (decoded['version'] != backupVersion) {
      throw FormatException('Versão de backup não suportada: ${decoded['version']}.');
    }
    final rawData = decoded['data'];
    if (rawData is! Map<String, dynamic>) throw const FormatException('A estrutura de dados do backup é inválida.');
    final backupTables = rawData.keys.toSet();
    if (backupTables.length != _backupTables.length || !backupTables.containsAll(_backupTables)) {
      throw const FormatException('O backup não contém exatamente as tabelas esperadas por esta versão do Orva.');
    }

    final allowedColumns = <String, Set<String>>{
      'categories': {'id','name','scope','created_at','updated_at'},
      'goals': {'id','title','description','period','category','start_date','deadline','metric_name','target_value','unit','progress_value','progress_mode','parent_id','status','created_at','updated_at'},
      'goal_progress_history': {'id','goal_id','progress_value','note','recorded_at'},
      'checklists': {'id','title','description','recurrence','weekdays_json','scheduled_date','start_date','end_date','is_template','is_active','created_at','updated_at'},
      'checklist_items': {'id','checklist_id','title','order_index','goal_id','is_active','created_at','updated_at'},
      'checklist_occurrences': {'id','checklist_id','reference_date','created_at'},
      'checklist_occurrence_items': {'id','occurrence_id','checklist_item_id','title_snapshot','order_snapshot','completed','completed_at'},
      'routine_blocks': {'id','title','category','start_minute','end_minute','block_kind','weekday','specific_date','template_name','goal_id','hobby_id','created_at','updated_at'},
      'hobbies': {'id','name','description','category','weekly_target_minutes','is_active','created_at','updated_at'},
      'routine_templates': {'id','name','description','created_at','updated_at'},
      'routine_template_blocks': {'id','template_id','title','category','start_minute','end_minute','weekday','goal_id','hobby_id','order_index'},
      'hobby_sessions': {'id','hobby_id','session_date','duration_minutes','start_minute','end_minute','note','created_at'},
      'notes': {'id','title','content','tags_json','created_at','updated_at'},
      'journal_entries': {'id','entry_date','content','mood','tags_json','created_at','updated_at'},
      'weight_entries': {'id','measured_at','weight_kg','note','created_at'},
      'settings': {'setting_key','setting_value','updated_at'},
    };

    for (final table in _backupTables) {
      final tableRows = rawData[table];
      if (tableRows is! List) throw FormatException('A tabela "$table" não existe ou não é uma lista válida.');
      for (final item in tableRows) {
        if (item is! Map<String, dynamic>) throw FormatException('Há um registro inválido em "$table".');
        final keys = item.keys.toSet();
        final expected = allowedColumns[table]!;
        if (keys.length != expected.length || !expected.containsAll(keys)) {
          throw FormatException('Os campos do registro em "$table" estão incompletos ou não são reconhecidos.');
        }
        if (table == 'settings') {
          if (item['setting_key'] is! String || (item['setting_key'] as String).isEmpty) {
            throw const FormatException('Há uma preferência sem chave no backup.');
          }
        } else if (item['id'] is! String || (item['id'] as String).isEmpty) {
          throw FormatException('Há um registro sem identificador em "$table".');
        }
      }
    }

    await db.transaction(() async {
      await execute('PRAGMA defer_foreign_keys = ON');
      for (final table in [
        'checklist_occurrence_items','checklist_occurrences','checklist_items','checklists',
        'goal_progress_history','routine_blocks','routine_template_blocks','routine_templates','hobby_sessions','hobbies','journal_entries','weight_entries','notes','goals','categories',
      ]) {
        await execute('DELETE FROM $table');
      }
      // Preserva PIN e preferências de bloqueio existentes: o backup nunca
      // contém essas chaves, e importar não deve desativar a proteção local.
      await execute(
        'DELETE FROM settings WHERE setting_key NOT IN (${_settingsKeysExcludedFromBackup.map((_) => '?').join(',')})',
        _settingsKeysExcludedFromBackup.toList(),
      );
      for (final table in _backupTables) {
        final tableRows = rawData[table] as List<dynamic>;
        for (final raw in tableRows) {
          final record = Map<String, dynamic>.from(raw as Map<String, dynamic>);
          if (record.isEmpty) continue;
          if (table == 'settings' && _settingsKeysExcludedFromBackup.contains(record['setting_key'])) {
            continue; // defesa extra: nunca aceitar PIN/flags de segurança vindos de um arquivo de backup.
          }
          final columns = record.keys.toList();
          final marks = List.filled(columns.length, '?').join(',');
          await execute('INSERT INTO $table (${columns.join(',')}) VALUES ($marks)', columns.map((key) => record[key]).toList());
        }
      }
    });
  }

  Object? _nullable(String? value) => value == null || value.trim().isEmpty ? null : value.trim();
}

final themeNameProvider = FutureProvider<String>((ref) async {
  return await ref.watch(repositoryProvider).getSetting('theme') ?? 'light';
});

final userNameProvider = FutureProvider<String?>((ref) async {
  final value = await ref.watch(repositoryProvider).getSetting('user_name');
  return value == null || value.trim().isEmpty ? null : value.trim();
});

final lockEnabledProvider = FutureProvider<bool>((ref) async {
  return ref.watch(repositoryProvider).isLockEnabled();
});

final biometricEnabledProvider = FutureProvider<bool>((ref) async {
  return ref.watch(repositoryProvider).isBiometricEnabled();
});

final quotesEnabledProvider = FutureProvider<bool>((ref) async {
  final value = await ref.watch(repositoryProvider).getSetting('quotes_enabled');
  return value != '0'; // ativado por padrão
});
