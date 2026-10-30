import 'dart:convert';

import 'package:drift/drift.dart';

import 'orva_repository.dart';

extension HabitsRepository on OrvaRepository {
  Future<List<Map<String, Object?>>> getHabits({bool includeInactive = false}) =>
      rows('''
        SELECT h.*,
          (SELECT COALESCE(SUM(hl.quantity),0) FROM habit_logs hl WHERE hl.habit_id=h.id) AS total_quantity,
          (SELECT COUNT(*) FROM habit_logs hl WHERE hl.habit_id=h.id) AS log_count
        FROM habits h
        ${includeInactive ? '' : 'WHERE h.is_active=1'}
        ORDER BY h.is_active DESC, h.name COLLATE NOCASE
      ''');

  Future<void> saveHabit({
    String? id,
    required String name,
    String unit = 'vezes',
    double? targetValue,
    String category = '',
    List<int> activeDays = const [],
    bool active = true,
  }) async {
    if (name.trim().isEmpty) throw ArgumentError('Informe o nome do hábito.');
    if (unit.trim().isEmpty) throw ArgumentError('Informe a unidade.');
    if (targetValue != null && targetValue <= 0) throw ArgumentError('A meta deve ser maior que zero.');
    if (activeDays.any((d) => d < 1 || d > 7)) throw ArgumentError('Dia da semana inválido.');
    final now = timestamp();
    final days = (activeDays.toSet().toList()..sort());
    if (id == null) {
      await execute('''
        INSERT INTO habits(id,name,unit,target_value,category,active_days_json,is_active,created_at,updated_at)
        VALUES(?,?,?,?,?,?,?,?,?)
      ''', [newId(), name.trim(), unit.trim(), targetValue, category.trim(), jsonEncode(days), active ? 1 : 0, now, now]);
    } else {
      await execute('''
        UPDATE habits SET name=?,unit=?,target_value=?,category=?,active_days_json=?,is_active=?,updated_at=? WHERE id=?
      ''', [name.trim(), unit.trim(), targetValue, category.trim(), jsonEncode(days), active ? 1 : 0, now, id]);
    }
    await _rememberCategorySafe(category, 'habits');
  }

  Future<void> deleteHabit(String id) =>
      execute('DELETE FROM habits WHERE id=?', [id]);

  Future<List<Map<String, Object?>>> getHabitLogs(String habitId, {DateTime? from, DateTime? to}) {
    final conditions = <String>['habit_id=?'];
    final variables = <Variable<Object>>[Variable.withString(habitId)];
    if (from != null) {
      conditions.add('log_date >= ?');
      variables.add(Variable.withString(dateKey(from)));
    }
    if (to != null) {
      conditions.add('log_date <= ?');
      variables.add(Variable.withString(dateKey(to)));
    }
    return rows(
      'SELECT * FROM habit_logs WHERE ${conditions.join(' AND ')} ORDER BY log_date DESC',
      variables,
    );
  }

  Future<void> logHabit({
    required String habitId,
    required DateTime date,
    required double quantity,
    String note = '',
  }) async {
    if (quantity < 0) throw ArgumentError('A quantidade não pode ser negativa.');
    final key = dateKey(date);
    final now = timestamp();
    final existing = await rows(
      'SELECT id FROM habit_logs WHERE habit_id=? AND log_date=?',
      [Variable.withString(habitId), Variable.withString(key)],
    );
    if (existing.isEmpty) {
      await execute('''
        INSERT INTO habit_logs(id,habit_id,log_date,quantity,note,created_at,updated_at)
        VALUES(?,?,?,?,?,?,?)
      ''', [newId(), habitId, key, quantity, note.trim(), now, now]);
    } else {
      await execute('''
        UPDATE habit_logs SET quantity=?,note=?,updated_at=? WHERE habit_id=? AND log_date=?
      ''', [quantity, note.trim(), now, habitId, key]);
    }
  }

  Future<void> deleteHabitLog(String habitId, DateTime date) =>
      execute('DELETE FROM habit_logs WHERE habit_id=? AND log_date=?',
          [habitId, dateKey(date)]);

  Future<double> habitTotal(String habitId, {DateTime? from, DateTime? to}) async {
    final logs = await getHabitLogs(habitId, from: from, to: to);
    return logs.fold<double>(0, (sum, row) => sum + (row['quantity'] as num? ?? 0).toDouble());
  }

  // Safe category remember without touching private members.
  Future<void> _rememberCategorySafe(String rawName, String scope) async {
    final name = rawName.trim();
    if (name.isEmpty) return;
    final existing = await rows('SELECT id FROM categories WHERE scope=? AND name=?',
        [Variable.withString(scope), Variable.withString(name)]);
    if (existing.isEmpty) {
      final now = timestamp();
      await execute('INSERT OR IGNORE INTO categories(id,name,scope,created_at,updated_at) VALUES(?,?,?,?,?)',
          [newId(), name, scope, now, now]);
    }
  }
}

