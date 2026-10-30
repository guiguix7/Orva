import 'orva_repository.dart';

extension CountdownsRepository on OrvaRepository {
  Future<List<Map<String, Object?>>> getCountdowns({bool includeArchived = false}) =>
      rows('''
        SELECT * FROM countdowns
        ${includeArchived ? '' : 'WHERE is_archived=0'}
        ORDER BY is_archived ASC, target_date ASC
      ''');

  Future<void> saveCountdown({
    String? id,
    required String title,
    required DateTime targetDate,
    String category = '',
    String description = '',
    bool archived = false,
  }) async {
    if (title.trim().isEmpty) throw ArgumentError('Informe o título da contagem regressiva.');
    final now = timestamp();
    final key = dateKey(targetDate);
    if (id == null) {
      await execute('''
        INSERT INTO countdowns(id,title,target_date,category,description,is_archived,created_at,updated_at)
        VALUES(?,?,?,?,?,?,?,?)
      ''', [newId(), title.trim(), key, category.trim(), description.trim(), archived ? 1 : 0, now, now]);
    } else {
      await execute('''
        UPDATE countdowns SET title=?,target_date=?,category=?,description=?,is_archived=?,updated_at=? WHERE id=?
      ''', [title.trim(), key, category.trim(), description.trim(), archived ? 1 : 0, now, id]);
    }
  }

  Future<void> deleteCountdown(String id) =>
      execute('DELETE FROM countdowns WHERE id=?', [id]);

  Future<void> archiveCountdown(String id, bool archived) async {
    await execute('UPDATE countdowns SET is_archived=?,updated_at=? WHERE id=?',
        [archived ? 1 : 0, timestamp(), id]);
  }

  int countdownDaysRemaining(DateTime target, {DateTime? now}) {
    final today = DateTime((now ?? DateTime.now()).year, (now ?? DateTime.now()).month, (now ?? DateTime.now()).day);
    final day = DateTime(target.year, target.month, target.day);
    return day.difference(today).inDays;
  }
}