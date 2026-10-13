import 'dart:convert';

import 'package:drift/drift.dart';

import 'orva_repository.dart';

DateTime _obligationDateOnly(DateTime date) => DateTime(date.year,date.month,date.day);
bool _minuteRangeWraps(int start,int end)=>end<start;
bool _obligationMatches(Map<String,Object?> rule,DateTime date){
  final key='${date.year.toString().padLeft(4,'0')}-${date.month.toString().padLeft(2,'0')}-${date.day.toString().padLeft(2,'0')}';
  final start=rule['start_date'] as String;
  final end=rule['end_date'] as String?;
  if(key.compareTo(start)<0 || (end!=null && key.compareTo(end)>0)) return false;
  switch(rule['recurrence']){
    case 'once': return key==start;
    case 'daily': return true;
    case 'weekly':
    case 'custom':
      try{
        final days=(jsonDecode(rule['weekdays_json'] as String) as List)
          .whereType<num>().map((value)=>value.toInt()).toSet();
        return days.contains(date.weekday);
      }catch(_){return false;}
    default:return false;
  }
}

/// Recurring obligation rules produce snapshots lazily for requested dates.
/// Overnight occurrences belong to the date they start on and are split only
/// for day-level schedule calculations, never duplicated as a new occurrence.
extension ObligationsRepository on OrvaRepository {
  Future<List<Map<String,Object?>>> getObligationRules({bool includeInactive=false}) =>
    rows('''
      SELECT r.*,
        (SELECT COUNT(*) FROM obligation_occurrences o WHERE o.rule_id=r.id) AS occurrence_count
      FROM obligation_rules r
      ${includeInactive?'':'WHERE r.is_active=1'}
      ORDER BY r.is_active DESC,r.start_minute,r.name COLLATE NOCASE
    ''');

  Future<void> saveObligationRule({
    String? id,
    required String name,
    String category='Pessoal',
    required int startMinute,
    required int endMinute,
    required String recurrence,
    List<int> weekdays=const [],
    required DateTime startDate,
    DateTime? endDate,
    String priority='normal',
    bool active=true,
  }) async{
    if(name.trim().isEmpty) throw ArgumentError('Informe o nome da obrigação.');
    if(startMinute<0 || startMinute>=1440 || endMinute<0 || endMinute>=1440 || startMinute==endMinute){
      throw ArgumentError('Informe horários válidos. Para atravessar a meia-noite, escolha um fim menor que o início.');
    }
    if(!const {'once','daily','weekly','custom'}.contains(recurrence)){
      throw ArgumentError('Recorrência inválida.');
    }
    if((recurrence=='weekly'||recurrence=='custom') && weekdays.isEmpty){
      throw ArgumentError('Selecione pelo menos um dia da semana.');
    }
    if(endDate!=null && _dateKeyForObligation(endDate).compareTo(_dateKeyForObligation(startDate))<0){
      throw ArgumentError('A data final deve ser igual ou posterior à inicial.');
    }
    if(!const {'low','normal','high'}.contains(priority)){
      throw ArgumentError('Prioridade inválida.');
    }
    final days=weekdays.toSet().toList()..sort();
    if(days.any((day)=>day<1||day>7)) throw ArgumentError('Dia da semana inválido.');
    final now=timestamp();
    if(id==null){
      await execute('''
        INSERT INTO obligation_rules(id,name,category,start_minute,end_minute,recurrence,weekdays_json,
          start_date,end_date,priority,is_active,created_at,updated_at)
        VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?)
      ''',[newId(),name.trim(),category.trim(),startMinute,endMinute,recurrence,jsonEncode(days),
        _dateKeyForObligation(startDate),endDate==null?null:_dateKeyForObligation(endDate),
        priority,active?1:0,now,now]);
    }else{
      await db.transaction(() async {
        await execute('''
          UPDATE obligation_rules SET name=?,category=?,start_minute=?,end_minute=?,recurrence=?,weekdays_json=?,
            start_date=?,end_date=?,priority=?,is_active=?,updated_at=? WHERE id=?
        ''',[name.trim(),category.trim(),startMinute,endMinute,recurrence,jsonEncode(days),
          _dateKeyForObligation(startDate),endDate==null?null:_dateKeyForObligation(endDate),
          priority,active?1:0,now,id]);
        // Future uncompleted projections without an explicit exception are a
        // cache, not history. Remove them so they are regenerated from the
        // updated rule on demand; completed and exception snapshots remain.
        await execute('''
          DELETE FROM obligation_occurrences
          WHERE rule_id=? AND occurrence_date>=? AND status='planned'
            AND NOT EXISTS (
              SELECT 1 FROM obligation_exceptions e
              WHERE e.rule_id=obligation_occurrences.rule_id
                AND e.occurrence_date=obligation_occurrences.occurrence_date
            )
        ''',[id,_dateKeyForObligation(DateTime.now())]);
      });
    }
  }

  Future<void> setObligationRuleActive(String id,bool active) async {
    await db.transaction(() async {
      await execute('UPDATE obligation_rules SET is_active=?,updated_at=? WHERE id=?',[active?1:0,timestamp(),id]);
      if (!active) {
        // Pausing a rule removes future schedule projections, while keeping
        // completed occurrences and the recorded history untouched.
        await execute('''
          DELETE FROM obligation_occurrences
          WHERE rule_id=? AND occurrence_date>=? AND status!='completed'
        ''',[id,_dateKeyForObligation(DateTime.now())]);
        await execute('DELETE FROM obligation_exceptions WHERE rule_id=? AND occurrence_date>=?',
          [id,_dateKeyForObligation(DateTime.now())]);
      }
    });
  }

  Future<void> saveObligationException({
    required String ruleId,
    required DateTime occurrenceDate,
    required String action,
    String? overrideName,
    String? overrideCategory,
    int? overrideStartMinute,
    int? overrideEndMinute,
    String note='',
  }) async{
    if(!const {'skip','override'}.contains(action)) throw ArgumentError('Exceção inválida.');
    if(action=='override'){
      if((overrideName??'').trim().isEmpty) throw ArgumentError('Informe o nome da ocorrência alterada.');
      if(overrideStartMinute==null||overrideEndMinute==null||
          overrideStartMinute<0||overrideStartMinute>=1440||
          overrideEndMinute<0||overrideEndMinute>=1440||
          overrideStartMinute==overrideEndMinute){
        throw ArgumentError('Informe horários válidos para a exceção.');
      }
    }
    final ruleRows=await rows('SELECT * FROM obligation_rules WHERE id=?',[Variable.withString(ruleId)]);
    if(ruleRows.isEmpty) throw ArgumentError('Regra de obrigação não encontrada.');
    final rule=ruleRows.first;
    final day=_dateKeyForObligation(occurrenceDate);
    final existing=await rows('SELECT id FROM obligation_exceptions WHERE rule_id=? AND occurrence_date=?',
      [Variable.withString(ruleId),Variable.withString(day)]);
    final now=timestamp();
    if(existing.isEmpty){
      await execute('''
        INSERT INTO obligation_exceptions(id,rule_id,occurrence_date,action,override_name,override_category,
          override_start_minute,override_end_minute,note,created_at,updated_at)
        VALUES(?,?,?,?,?,?,?,?,?,?,?)
      ''',[newId(),ruleId,day,action,_trimObligation(overrideName),_trimObligation(overrideCategory),
        overrideStartMinute,overrideEndMinute,note.trim(),now,now]);
    }else{
      await execute('''
        UPDATE obligation_exceptions SET action=?,override_name=?,override_category=?,override_start_minute=?,
          override_end_minute=?,note=?,updated_at=? WHERE rule_id=? AND occurrence_date=?
      ''',[action,_trimObligation(overrideName),_trimObligation(overrideCategory),
        overrideStartMinute,overrideEndMinute,note.trim(),now,ruleId,day]);
    }

    final occ=await rows('SELECT * FROM obligation_occurrences WHERE rule_id=? AND occurrence_date=?',
      [Variable.withString(ruleId),Variable.withString(day)]);
    // Completed historical facts are immutable, even when an exception is
    // edited later. Uncompleted occurrences follow the explicit exception.
    if(occ.isNotEmpty && occ.first['status']!='completed'){
      final start=action=='override'?overrideStartMinute!: (rule['start_minute'] as num).toInt();
      final end=action=='override'?overrideEndMinute!: (rule['end_minute'] as num).toInt();
      final name=action=='override'?overrideName!.trim():rule['name'] as String;
      final category=action=='override'?_trimObligation(overrideCategory)??rule['category'] as String:rule['category'] as String;
      await execute('''
        UPDATE obligation_occurrences SET name_snapshot=?,category_snapshot=?,start_minute=?,end_minute=?,
          ends_next_day=?,status=?,note_snapshot=?,updated_at=? WHERE rule_id=? AND occurrence_date=?
      ''',[name,category,start,end,_minuteRangeWraps(start,end)?1:0,action=='skip'?'skipped':'planned',
        note.trim(),now,ruleId,day]);
    }
  }

  Future<void> clearObligationException(String ruleId,DateTime occurrenceDate) async{
    final day=_dateKeyForObligation(occurrenceDate);
    final occ=await rows('SELECT * FROM obligation_occurrences WHERE rule_id=? AND occurrence_date=?',
      [Variable.withString(ruleId),Variable.withString(day)]);
    await execute('DELETE FROM obligation_exceptions WHERE rule_id=? AND occurrence_date=?',[ruleId,day]);
    if(occ.isNotEmpty && occ.first['status']!='completed'){
      final rules=await rows('SELECT * FROM obligation_rules WHERE id=?',[Variable.withString(ruleId)]);
      if(rules.isNotEmpty){
        final rule=rules.first;
        final start=(rule['start_minute'] as num).toInt();
        final end=(rule['end_minute'] as num).toInt();
        await execute('''
          UPDATE obligation_occurrences SET name_snapshot=?,category_snapshot=?,start_minute=?,end_minute=?,
            ends_next_day=?,status='planned',note_snapshot='',updated_at=? WHERE rule_id=? AND occurrence_date=?
        ''',[rule['name'],rule['category'],start,end,_minuteRangeWraps(start,end)?1:0,timestamp(),ruleId,day]);
      }
    }
  }

  Future<void> _ensureObligationsForDate(DateTime date) async{
    final rules=await rows('SELECT * FROM obligation_rules WHERE is_active=1');
    final key=_dateKeyForObligation(date);
    for(final rule in rules){
      if(!_obligationMatches(rule,date)) continue;
      final exists=await rows('SELECT id FROM obligation_occurrences WHERE rule_id=? AND occurrence_date=?',
        [Variable.withString(rule['id'] as String),Variable.withString(key)]);
      if(exists.isNotEmpty) continue;
      final exceptionRows=await rows('SELECT * FROM obligation_exceptions WHERE rule_id=? AND occurrence_date=?',
        [Variable.withString(rule['id'] as String),Variable.withString(key)]);
      final exception=exceptionRows.isEmpty?null:exceptionRows.first;
      final action=exception?['action'] as String?;
      final start=action=='override'?(exception!['override_start_minute'] as num).toInt():(rule['start_minute'] as num).toInt();
      final end=action=='override'?(exception!['override_end_minute'] as num).toInt():(rule['end_minute'] as num).toInt();
      final name=action=='override'?exception!['override_name'] as String:rule['name'] as String;
      final category=action=='override'?(exception!['override_category'] as String? ?? rule['category'] as String):rule['category'] as String;
      await execute('''
        INSERT OR IGNORE INTO obligation_occurrences
          (id,rule_id,occurrence_date,name_snapshot,category_snapshot,start_minute,end_minute,ends_next_day,
           status,note_snapshot,created_at,updated_at)
        VALUES(?,?,?,?,?,?,?,?,?,?,?,?)
      ''',[newId(),rule['id'],key,name,category,start,end,_minuteRangeWraps(start,end)?1:0,
        action=='skip'?'skipped':'planned',exception?['note'] as String? ?? '',timestamp(),timestamp()]);
    }
  }

  Future<List<Map<String,Object?>>> getObligationOccurrencesForDate(
    DateTime date,{bool includeSkipped=true}) async{
    await _ensureObligationsForDate(date);
    return rows('''
      SELECT o.*,r.priority,r.is_active AS rule_active,e.action AS exception_action
      FROM obligation_occurrences o JOIN obligation_rules r ON r.id=o.rule_id
      LEFT JOIN obligation_exceptions e ON e.rule_id=o.rule_id AND e.occurrence_date=o.occurrence_date
      WHERE o.occurrence_date=? ${includeSkipped?'':'AND o.status!=\'skipped\''}
      ORDER BY o.start_minute,o.name_snapshot COLLATE NOCASE
    ''',[Variable.withString(_dateKeyForObligation(date))]);
  }

  Future<List<Map<String,Object?>>> getObligationTimeBlocksForDate(DateTime date) async{
    final target=_obligationDateOnly(date);
    final previous=DateTime(target.year,target.month,target.day-1);
    await _ensureObligationsForDate(target);
    await _ensureObligationsForDate(previous);
    final today=await getObligationOccurrencesForDate(target,includeSkipped:false);
    final yesterday=await rows('''
      SELECT * FROM obligation_occurrences
      WHERE occurrence_date=? AND ends_next_day=1 AND end_minute>0 AND status!='skipped'
      ORDER BY start_minute
    ''',[Variable.withString(_dateKeyForObligation(previous))]);
    final blocks=<Map<String,Object?>>[];
    for(final occurrence in today){
      final start=(occurrence['start_minute'] as num).toInt();
      final end=(occurrence['end_minute'] as num).toInt();
      final wraps=(occurrence['ends_next_day'] as num).toInt()==1;
      blocks.add({
        'id':'obligation:${occurrence['id']}',
        'obligation_occurrence_id':occurrence['id'],
        'obligation_rule_id':occurrence['rule_id'],
        'title':occurrence['name_snapshot'],
        'category':occurrence['category_snapshot'],
        'start_minute':start,
        'end_minute':wraps?1440:end,
        'block_kind':'obligation',
        'obligation_date':occurrence['occurrence_date'],
        'obligation_status':occurrence['status'],
        'continues_from_previous_day':0,
        'ends_next_day':wraps?1:0,
      });
    }
    for(final occurrence in yesterday){
      blocks.add({
        'id':'obligation-continuation:${occurrence['id']}',
        'obligation_occurrence_id':occurrence['id'],
        'obligation_rule_id':occurrence['rule_id'],
        'title':'${occurrence['name_snapshot']} · continuação',
        'category':occurrence['category_snapshot'],
        'start_minute':0,
        'end_minute':(occurrence['end_minute'] as num).toInt(),
        'block_kind':'obligation',
        'obligation_date':occurrence['occurrence_date'],
        'obligation_status':occurrence['status'],
        'continues_from_previous_day':1,
        'ends_next_day':0,
      });
    }
    blocks.sort((a,b)=>(a['start_minute'] as int).compareTo(b['start_minute'] as int));
    return blocks;
  }

  Future<void> setObligationOccurrenceCompleted(String occurrenceId,bool completed) async{
    final found=await rows('SELECT status FROM obligation_occurrences WHERE id=?',[Variable.withString(occurrenceId)]);
    if(found.isEmpty) throw ArgumentError('Ocorrência não encontrada.');
    if(found.first['status']=='skipped') throw StateError('Remova a exceção antes de alterar uma ocorrência dispensada.');
    await execute('UPDATE obligation_occurrences SET status=?,updated_at=? WHERE id=?',
      [completed?'completed':'planned',timestamp(),occurrenceId]);
  }

  Future<List<Map<String,Object?>>> getObligationHistory(String ruleId,{int limit=100}) => rows('''
    SELECT * FROM obligation_occurrences WHERE rule_id=?
    ORDER BY occurrence_date DESC LIMIT ${limit.clamp(1,500)}
  ''',[Variable.withString(ruleId)]);
}

String _dateKeyForObligation(DateTime date) =>
  '${date.year.toString().padLeft(4,'0')}-${date.month.toString().padLeft(2,'0')}-${date.day.toString().padLeft(2,'0')}';
String? _trimObligation(String? value)=>value==null||value.trim().isEmpty?null:value.trim();
