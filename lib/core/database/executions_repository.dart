import 'package:drift/drift.dart';

import 'orva_repository.dart';

/// Real executions ("realidade") are stored separately from planned blocks.
/// A row here means time was actually spent; planned blocks are never counted
/// as completed automatically.
extension ExecutionsRepository on OrvaRepository {
  Future<void> saveExecution({
    String? id,
    String referenceType = 'custom',
    String? referenceId,
    String category = '',
    required String title,
    required DateTime startedAt,
    DateTime? endedAt,
    required int durationMinutes,
    String source = 'manual',
    DateTime? referenceDate,
    String note = '',
  }) async {
    if (title.trim().isEmpty) throw ArgumentError('Informe o título da execução.');
    if (durationMinutes <= 0) throw ArgumentError('A duração deve ser maior que zero.');
    if (!const {'routine_block', 'obligation', 'hobby', 'study', 'habit', 'custom'}
        .contains(referenceType)) {
      throw ArgumentError('Tipo de referência inválido.');
    }
    if (!const {'manual', 'timer', 'pomodoro'}.contains(source)) {
      throw ArgumentError('Origem de registro inválida.');
    }
    final refDate = referenceDate ?? startedAt;
    final key = dateKey(refDate);
    final now = timestamp();
    if (id == null) {
      await execute('''
        INSERT INTO executions(id,reference_type,reference_id,category,title,started_at,ended_at,
          duration_minutes,source,reference_date,note,created_at)
        VALUES(?,?,?,?,?,?,?,?,?,?,?,?)
      ''', [
        newId(), referenceType, _nullable(referenceId), category.trim(), title.trim(),
        startedAt.toIso8601String(), endedAt?.toIso8601String(), durationMinutes, source, key, note.trim(), now,
      ]);
    } else {
      await execute('''
        UPDATE executions SET reference_type=?,reference_id=?,category=?,title=?,started_at=?,ended_at=?,
          duration_minutes=?,source=?,reference_date=?,note=? WHERE id=?
      ''', [
        referenceType, _nullable(referenceId), category.trim(), title.trim(),
        startedAt.toIso8601String(), endedAt?.toIso8601String(), durationMinutes, source, key, note.trim(), id,
      ]);
    }
  }

  Future<void> deleteExecution(String id) =>
      execute('DELETE FROM executions WHERE id=?', [id]);

  Future<List<Map<String, Object?>>> getExecutions({
    DateTime? from,
    DateTime? to,
    String? category,
  }) {
    final conditions = <String>[];
    final variables = <Variable<Object>>[];
    if (from != null) {
      conditions.add('reference_date >= ?');
      variables.add(Variable.withString(dateKey(from)));
    }
    if (to != null) {
      conditions.add('reference_date <= ?');
      variables.add(Variable.withString(dateKey(to)));
    }
    if (category != null && category.trim().isNotEmpty) {
      conditions.add('category = ?');
      variables.add(Variable.withString(category.trim()));
    }
    final where = conditions.isEmpty ? '' : 'WHERE ${conditions.join(' AND ')}';
    return rows('SELECT * FROM executions $where ORDER BY started_at DESC', variables);
  }

  Future<int> executionMinutesForDate(DateTime date, {String? category}) async {
    final rows = await getExecutions(from: date, to: date, category: category);
    return rows.fold<int>(0, (sum, row) => sum + (row['duration_minutes'] as int? ?? 0));
  }

  Future<Map<String, int>> executionMinutesByCategory({
    DateTime? from,
    DateTime? to,
  }) async {
    final rows = await getExecutions(from: from, to: to);
    final totals = <String, int>{};
    for (final row in rows) {
      final category = (row['category'] as String?)?.trim();
      final key = (category == null || category.isEmpty) ? 'Sem categoria' : category;
      totals[key] = (totals[key] ?? 0) + (row['duration_minutes'] as int? ?? 0);
    }
    return totals;
  }

  String? _nullable(String? value) => value == null || value.trim().isEmpty ? null : value.trim();
}
