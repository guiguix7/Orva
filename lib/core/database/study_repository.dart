import 'package:drift/drift.dart';

import 'orva_repository.dart';

/// Study-related operations kept separate from the core repository to keep
/// the domain understandable. All records remain in the local SQLite database.
extension StudyRepository on OrvaRepository {
  Future<List<Map<String, Object?>>> getStudySubjects({
    bool includeArchived = false,
  }) =>
      rows('''
        SELECT s.*,
          COALESCE((SELECT SUM(ss.duration_minutes) FROM study_sessions ss
            WHERE ss.subject_id=s.id),0) AS total_minutes,
          (SELECT COUNT(*) FROM study_topics t WHERE t.subject_id=s.id) AS topic_count,
          (SELECT COUNT(*) FROM study_sessions ss WHERE ss.subject_id=s.id) AS session_count
        FROM study_subjects s
        ${includeArchived ? '' : 'WHERE s.is_active=1'}
        ORDER BY s.is_active DESC, s.name COLLATE NOCASE
      ''');

  Future<void> saveStudySubject({
    String? id,
    required String name,
    String description = '',
    int? colorValue,
    String? goalId,
  }) async {
    if (name.trim().isEmpty) throw ArgumentError('Informe o nome da matéria.');
    if (name.trim().length > 100) throw ArgumentError('Use até 100 caracteres no nome da matéria.');
    if (goalId != null) {
      final goals = await rows("SELECT id FROM goals WHERE id=? AND status!='archived'",
          [Variable.withString(goalId)]);
      if (goals.isEmpty) throw ArgumentError('A meta vinculada não existe mais.');
    }
    final now = timestamp();
    if (id == null) {
      await execute('''
        INSERT INTO study_subjects
          (id,name,description,color_value,goal_id,is_active,created_at,updated_at)
        VALUES (?,?,?,?,?,1,?,?)
      ''', [newId(), name.trim(), description.trim(), colorValue, goalId, now, now]);
    } else {
      await execute('''
        UPDATE study_subjects SET name=?,description=?,color_value=?,goal_id=?,updated_at=?
        WHERE id=?
      ''', [name.trim(), description.trim(), colorValue, goalId, now, id]);
    }
  }

  Future<void> setStudySubjectActive(String id, bool active) => execute(
      'UPDATE study_subjects SET is_active=?,updated_at=? WHERE id=?',
      [active ? 1 : 0, timestamp(), id]);

  Future<List<Map<String, Object?>>> getStudyTopics(String subjectId) => rows('''
    SELECT t.*, p.name AS parent_name,
      (SELECT COUNT(*) FROM study_sessions ss WHERE ss.topic_id=t.id) AS session_count,
      (SELECT MAX(sr.reviewed_at) FROM study_reviews sr WHERE sr.topic_id=t.id) AS last_reviewed_at
    FROM study_topics t
    LEFT JOIN study_topics p ON p.id=t.parent_topic_id
    WHERE t.subject_id=?
    ORDER BY COALESCE(t.parent_topic_id,''),t.order_index,t.name COLLATE NOCASE
  ''', [Variable.withString(subjectId)]);

  Future<void> saveStudyTopic({
    String? id,
    required String subjectId,
    String? parentTopicId,
    required String name,
    String description = '',
    String status = 'not_started',
    int orderIndex = 0,
  }) async {
    if (name.trim().isEmpty) throw ArgumentError('Informe o nome do assunto.');
    if (!const {'not_started','in_progress','completed'}.contains(status)) {
      throw ArgumentError('Estado do assunto inválido.');
    }
    final subjects = await rows('SELECT id FROM study_subjects WHERE id=? AND is_active=1',
        [Variable.withString(subjectId)]);
    if (subjects.isEmpty) throw ArgumentError('A matéria não existe ou está arquivada.');
    if (parentTopicId != null) {
      final parents = await rows('SELECT id,subject_id FROM study_topics WHERE id=?',
          [Variable.withString(parentTopicId)]);
      if (parents.isEmpty || parents.first['subject_id'] != subjectId || parentTopicId == id) {
        throw ArgumentError('Escolha um assunto pai da mesma matéria.');
      }
      // Prevent a cycle when moving an existing topic under one of its descendants.
      var cursor = parentTopicId;
      final visited = <String>{};
      while (cursor != null) {
        if (cursor == id) throw ArgumentError('Um assunto não pode ser filho de si próprio.');
        if (!visited.add(cursor)) throw StateError('A hierarquia de assuntos contém um ciclo.');
        final parent = await rows('SELECT parent_topic_id FROM study_topics WHERE id=?',
            [Variable.withString(cursor)]);
        cursor = parent.isEmpty ? null : parent.first['parent_topic_id'] as String?;
      }
    }
    final now = timestamp();
    if (id == null) {
      await execute('''
        INSERT INTO study_topics
          (id,subject_id,parent_topic_id,name,description,status,order_index,created_at,updated_at)
        VALUES (?,?,?,?,?,?,?,?,?)
      ''', [newId(),subjectId,parentTopicId,name.trim(),description.trim(),status,orderIndex,now,now]);
    } else {
      await execute('''
        UPDATE study_topics SET subject_id=?,parent_topic_id=?,name=?,description=?,status=?,order_index=?,updated_at=?
        WHERE id=?
      ''', [subjectId,parentTopicId,name.trim(),description.trim(),status,orderIndex,now,id]);
    }
  }

  Future<void> deleteStudyTopic(String id) async {
    final topics = await rows('SELECT id FROM study_topics WHERE parent_topic_id=?',
        [Variable.withString(id)]);
    if (topics.isNotEmpty) {
      throw StateError('Este assunto contém subtópicos. Mova ou exclua os subtópicos primeiro.');
    }
    final sessions = await rows('SELECT id FROM study_sessions WHERE topic_id=?',
        [Variable.withString(id)]);
    final reviews = await rows('SELECT id FROM study_reviews WHERE topic_id=?',
        [Variable.withString(id)]);
    if (sessions.isNotEmpty || reviews.isNotEmpty) {
      throw StateError('Este assunto tem histórico. Marque-o como concluído para preservar os registros.');
    }
    await execute('DELETE FROM study_topics WHERE id=?', [id]);
  }

  Future<List<Map<String, Object?>>> getStudySessions({
    String? subjectId,
    DateTime? date,
    int limit = 100,
  }) async {
    final clauses = <String>[];
    final vars = <Variable<Object>>[];
    if (subjectId != null) {
      clauses.add('ss.subject_id=?');
      vars.add(Variable.withString(subjectId));
    }
    if (date != null) {
      clauses.add('ss.session_date=?');
      vars.add(Variable.withString(dateKey(date)));
    }
    final where = clauses.isEmpty ? '' : 'WHERE ${clauses.join(' AND ')}';
    return rows('''
      SELECT ss.*,s.name AS subject_name,t.name AS topic_name,g.title AS goal_title
      FROM study_sessions ss
      JOIN study_subjects s ON s.id=ss.subject_id
      LEFT JOIN study_topics t ON t.id=ss.topic_id
      LEFT JOIN goals g ON g.id=ss.goal_id
      $where
      ORDER BY ss.session_date DESC,ss.start_minute DESC,ss.created_at DESC
      LIMIT ${limit.clamp(1,500)}
    ''', vars);
  }

  Future<void> saveStudySession({
    String? id,
    required String subjectId,
    String? topicId,
    String? goalId,
    required DateTime sessionDate,
    int? startMinute,
    required int durationMinutes,
    String note = '',
  }) async {
    if (durationMinutes < 1 || durationMinutes > 1440) {
      throw ArgumentError('A duração deve estar entre 1 minuto e 24 horas.');
    }
    if (startMinute != null && (startMinute < 0 || startMinute >= 1440)) {
      throw ArgumentError('Horário inicial inválido.');
    }
    final subject = await rows('SELECT id FROM study_subjects WHERE id=? AND is_active=1',
        [Variable.withString(subjectId)]);
    if (subject.isEmpty) throw ArgumentError('A matéria não existe ou está arquivada.');
    if (topicId != null) {
      final topic = await rows('SELECT id FROM study_topics WHERE id=? AND subject_id=?',
          [Variable.withString(topicId),Variable.withString(subjectId)]);
      if (topic.isEmpty) throw ArgumentError('O assunto precisa pertencer à matéria selecionada.');
    }
    if (goalId != null) {
      final goal = await rows("SELECT id FROM goals WHERE id=? AND status='active'",
          [Variable.withString(goalId)]);
      if (goal.isEmpty) throw ArgumentError('A meta vinculada não está ativa.');
    }
    final now = timestamp();
    if (id == null) {
      await execute('''
        INSERT INTO study_sessions
          (id,subject_id,topic_id,goal_id,session_date,start_minute,duration_minutes,note,created_at,updated_at)
        VALUES (?,?,?,?,?,?,?,?,?,?)
      ''', [newId(),subjectId,topicId,goalId,dateKey(sessionDate),startMinute,durationMinutes,note.trim(),now,now]);
    } else {
      await execute('''
        UPDATE study_sessions SET subject_id=?,topic_id=?,goal_id=?,session_date=?,start_minute=?,
          duration_minutes=?,note=?,updated_at=? WHERE id=?
      ''', [subjectId,topicId,goalId,dateKey(sessionDate),startMinute,durationMinutes,note.trim(),now,id]);
    }
  }

  Future<void> deleteStudySession(String id) => execute('DELETE FROM study_sessions WHERE id=?',[id]);

  Future<List<Map<String, Object?>>> getStudyReviews({
    String? subjectId,
    String? topicId,
    int limit = 100,
  }) {
    final clauses=<String>[];
    final vars=<Variable<Object>>[];
    if(subjectId!=null){clauses.add('r.subject_id=?');vars.add(Variable.withString(subjectId));}
    if(topicId!=null){clauses.add('r.topic_id=?');vars.add(Variable.withString(topicId));}
    return rows('''
      SELECT r.*,s.name AS subject_name,t.name AS topic_name
      FROM study_reviews r JOIN study_subjects s ON s.id=r.subject_id
      LEFT JOIN study_topics t ON t.id=r.topic_id
      ${clauses.isEmpty ? '' : 'WHERE ${clauses.join(' AND ')}'}
      ORDER BY r.reviewed_at DESC,r.created_at DESC LIMIT ${limit.clamp(1,500)}
    ''',vars);
  }

  Future<void> saveStudyReview({
    String? id,
    required String subjectId,
    String? topicId,
    required DateTime reviewedAt,
    String reviewKind = 'review',
    int? confidence,
    String note = '',
  }) async {
    if(confidence!=null && (confidence<1 || confidence>5)) {
      throw ArgumentError('A confiança deve estar entre 1 e 5.');
    }
    final subject=await rows('SELECT id FROM study_subjects WHERE id=?',
        [Variable.withString(subjectId)]);
    if(subject.isEmpty) throw ArgumentError('Matéria não encontrada.');
    if(topicId!=null){
      final topic=await rows('SELECT id FROM study_topics WHERE id=? AND subject_id=?',
          [Variable.withString(topicId),Variable.withString(subjectId)]);
      if(topic.isEmpty) throw ArgumentError('Assunto incompatível com a matéria.');
    }
    final now=timestamp();
    await execute('''
      INSERT INTO study_reviews(id,subject_id,topic_id,reviewed_at,review_kind,confidence,note,created_at)
      VALUES(?,?,?,?,?,?,?,?)
    ''',[id??newId(),subjectId,topicId,dateKey(reviewedAt),reviewKind,confidence,note.trim(),now]);
  }

  Future<Map<String,Object?>> getStudySummary({DateTime? from,DateTime? to}) async {
    final clauses=<String>[];
    final vars=<Variable<Object>>[];
    if(from!=null){clauses.add('session_date>=?');vars.add(Variable.withString(dateKey(from)));}
    if(to!=null){clauses.add('session_date<=?');vars.add(Variable.withString(dateKey(to)));}
    final where=clauses.isEmpty?'':'WHERE ${clauses.join(' AND ')}';
    final totals=await rows('''
      SELECT COUNT(*) AS sessions,COALESCE(SUM(duration_minutes),0) AS minutes,
        COUNT(DISTINCT session_date) AS study_days
      FROM study_sessions $where
    ''',vars);
    final reviewClauses=<String>[];
    final reviewVars=<Variable<Object>>[];
    if(from!=null){reviewClauses.add('reviewed_at>=?');reviewVars.add(Variable.withString(dateKey(from)));}
    if(to!=null){reviewClauses.add('reviewed_at<=?');reviewVars.add(Variable.withString(dateKey(to)));}
    final reviewWhere=reviewClauses.isEmpty?'':'WHERE ${reviewClauses.join(' AND ')}';
    final reviews=await rows('SELECT COUNT(*) AS count FROM study_reviews $reviewWhere',reviewVars);
    final row=totals.single;
    return {
      'sessions':(row['sessions'] as num).toInt(),
      'minutes':(row['minutes'] as num).toInt(),
      'studyDays':(row['study_days'] as num).toInt(),
      'reviews':(reviews.single['count'] as num).toInt(),
    };
  }
}
