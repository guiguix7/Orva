import 'package:drift/drift.dart';

import '../domain/comparison_scoring.dart';
import 'orva_repository.dart';

/// Persistence for the Beto/Alfredo comparison. Traits and their rules are
/// durable configuration; check-ins are the only evidence this module owns.
/// Record-based traits read habit logs and study sessions through their own
/// tables, so one activity is never entered twice.
const comparisonPeriodSettingKey = 'comparison_period';
const _comparisonSeededSettingKey = 'comparison_seeded';

extension ComparisonRepository on OrvaRepository {
  /// Creates the default presentation and editable trait templates once.
  /// Never seeds activity evidence or history.
  Future<void> ensureComparisonSeeded() async {
    final now = timestamp();
    await execute(
      '''INSERT OR IGNORE INTO comparison_profiles(role,display_name,description,updated_at)
      VALUES(?,?,?,?)''',
      [
        'alfredo',
        'Alfredo',
        'Disciplina, constância e o que você quer fortalecer.',
        now,
      ],
    );
    await execute(
      '''INSERT OR IGNORE INTO comparison_profiles(role,display_name,description,updated_at)
      VALUES(?,?,?,?)''',
      ['beto', 'Beto', 'Impulso, improviso e o que você quer reduzir.', now],
    );
    if (await getSetting(_comparisonSeededSettingKey) == '1') return;

    const templates =
        <
          ({
            String id,
            String label,
            String explanation,
            String side,
            String measurement,
            double threshold,
            String unit,
          })
        >[
          (
            id: 'tpl_leitura',
            label: 'Leu ou estudou',
            explanation:
                'Dias em que você reservou tempo para leitura ou estudo.',
            side: 'alfredo',
            measurement: 'manual',
            threshold: 5,
            unit: 'dias',
          ),
          (
            id: 'tpl_treino',
            label: 'Treinou',
            explanation: 'Dias com treino registrado por você.',
            side: 'alfredo',
            measurement: 'manual',
            threshold: 3,
            unit: 'dias',
          ),
          (
            id: 'tpl_tempo_estudo',
            label: 'Tempo de estudo',
            explanation:
                'Soma das sessões de estudo já registradas no módulo Estudos.',
            side: 'alfredo',
            measurement: 'study_minutes',
            threshold: 180,
            unit: 'min',
          ),
          (
            id: 'tpl_adiar',
            label: 'Adiou tarefas importantes',
            explanation: 'Dias em que você marcou, de forma consciente, que adiou algo importante.',
            side: 'beto',
            measurement: 'manual',
            threshold: 3,
            unit: 'dias',
          ),
        ];
    for (final template in templates) {
      await execute(
        '''INSERT OR IGNORE INTO comparison_traits(id,label,explanation,target_character,
          measurement_type,source_id,threshold,unit,weight,window_days,is_sensitive,is_active,created_at,updated_at)
        VALUES(?,?,?,?,?,NULL,?,?,1,0,0,1,?,?)''',
        [
          template.id,
          template.label,
          template.explanation,
          template.side,
          template.measurement,
          template.threshold,
          template.unit,
          now,
          now,
        ],
      );
    }
    await setSetting(_comparisonSeededSettingKey, '1');
  }

  Future<Map<String, Map<String, Object?>>> getComparisonProfiles() async {
    final result = await rows('SELECT * FROM comparison_profiles');
    return {for (final row in result) row['role'] as String: row};
  }

  Future<void> saveComparisonProfile({
    required ComparisonSide side,
    required String displayName,
    required String description,
  }) async {
    if (displayName.trim().isEmpty) {
      throw ArgumentError('Informe um nome para o personagem.');
    }
    await execute(
      '''INSERT INTO comparison_profiles(role,display_name,description,updated_at)
      VALUES(?,?,?,?)
      ON CONFLICT(role) DO UPDATE SET
        display_name=excluded.display_name,
        description=excluded.description,
        updated_at=excluded.updated_at''',
      [
        comparisonSideStorageValue(side),
        displayName.trim(),
        description.trim(),
        timestamp(),
      ],
    );
  }

  Future<List<Map<String, Object?>>> getComparisonTraits() => rows(
    'SELECT * FROM comparison_traits ORDER BY is_active DESC, created_at, label COLLATE NOCASE',
  );

  Future<void> saveComparisonTrait({
    String? id,
    required String label,
    String explanation = '',
    required ComparisonSide side,
    required TraitMeasurement measurement,
    String? sourceId,
    required double threshold,
    String unit = '',
    double weight = 1,
    int windowDays = 0,
    bool sensitive = false,
    bool active = true,
  }) async {
    if (label.trim().isEmpty) {
      throw ArgumentError('Informe um nome para o critério.');
    }
    if (!threshold.isFinite || threshold <= 0) {
      throw ArgumentError('O limiar deve ser maior que zero.');
    }
    if (!weight.isFinite || weight <= 0) {
      throw ArgumentError('O peso deve ser maior que zero.');
    }
    if (windowDays < 0 || windowDays > 365) {
      throw ArgumentError('A janela deve estar entre 0 e 365 dias.');
    }
    final sourceTable = switch (measurement) {
      TraitMeasurement.manualCheckin => null,
      TraitMeasurement.habitQuantity => 'habits',
      TraitMeasurement.studyMinutes => 'study_subjects',
    };
    String? resolvedSource;
    if (sourceTable != null) {
      final raw = sourceId?.trim() ?? '';
      if (raw.isEmpty) {
        throw ArgumentError('Selecione a origem dos registros deste critério.');
      }
      final existing = await rows('SELECT id FROM $sourceTable WHERE id=?', [
        Variable.withString(raw),
      ]);
      if (existing.isEmpty) {
        throw ArgumentError('A origem selecionada não existe mais.');
      }
      resolvedSource = raw;
    }
    // A sensitive trait is never enabled as a fact about the user without an
    // explicit opt-in, so it is stored disabled.
    final effectiveActive = sensitive ? false : active;
    final now = timestamp();
    if (id == null) {
      await execute(
        '''
        INSERT INTO comparison_traits(id,label,explanation,target_character,measurement_type,
          source_id,threshold,unit,weight,window_days,is_sensitive,is_active,created_at,updated_at)
        VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?,?)
      ''',
        [
          newId(),
          label.trim(),
          explanation.trim(),
          comparisonSideStorageValue(side),
          traitMeasurementStorageValue(measurement),
          resolvedSource,
          threshold,
          unit.trim(),
          weight,
          windowDays,
          sensitive ? 1 : 0,
          effectiveActive ? 1 : 0,
          now,
          now,
        ],
      );
    } else {
      await execute(
        '''
        UPDATE comparison_traits SET label=?,explanation=?,target_character=?,measurement_type=?,
          source_id=?,threshold=?,unit=?,weight=?,window_days=?,is_sensitive=?,is_active=?,updated_at=?
        WHERE id=?
      ''',
        [
          label.trim(),
          explanation.trim(),
          comparisonSideStorageValue(side),
          traitMeasurementStorageValue(measurement),
          resolvedSource,
          threshold,
          unit.trim(),
          weight,
          windowDays,
          sensitive ? 1 : 0,
          effectiveActive ? 1 : 0,
          now,
          id,
        ],
      );
    }
  }

  Future<void> setComparisonTraitActive(String traitId, bool active) => execute(
    'UPDATE comparison_traits SET is_active=?, updated_at=? WHERE id=?',
    [active ? 1 : 0, timestamp(), traitId],
  );

  Future<void> deleteComparisonTrait(String traitId) =>
      execute('DELETE FROM comparison_traits WHERE id=?', [traitId]);

  Future<List<Map<String, Object?>>> getComparisonCheckins(
    String traitId, {
    DateTime? from,
    DateTime? to,
  }) {
    final conditions = <String>['trait_id=?'];
    final variables = <Variable<Object>>[Variable.withString(traitId)];
    if (from != null) {
      conditions.add('checkin_date >= ?');
      variables.add(Variable.withString(dateKey(from)));
    }
    if (to != null) {
      conditions.add('checkin_date <= ?');
      variables.add(Variable.withString(dateKey(to)));
    }
    return rows(
      'SELECT * FROM comparison_checkins WHERE ${conditions.join(' AND ')} ORDER BY checkin_date DESC',
      variables,
    );
  }

  Future<bool> isComparisonCheckedIn(String traitId, DateTime date) async {
    final result = await rows(
      'SELECT id FROM comparison_checkins WHERE trait_id=? AND checkin_date=?',
      [Variable.withString(traitId), Variable.withString(dateKey(date))],
    );
    return result.isNotEmpty;
  }

  /// Idempotent per trait and local date: recording the same day twice updates
  /// the existing row instead of creating duplicate evidence.
  Future<void> setComparisonCheckin({
    required String traitId,
    required DateTime date,
    required bool recorded,
    String note = '',
  }) async {
    final key = dateKey(date);
    if (!recorded) {
      await execute(
        'DELETE FROM comparison_checkins WHERE trait_id=? AND checkin_date=?',
        [traitId, key],
      );
      return;
    }
    final now = timestamp();
    await execute(
      '''
      INSERT INTO comparison_checkins(id,trait_id,checkin_date,note,created_at,updated_at)
      VALUES(?,?,?,?,?,?)
      ON CONFLICT(trait_id, checkin_date) DO UPDATE SET note=excluded.note, updated_at=excluded.updated_at
    ''',
      [newId(), traitId, key, note.trim(), now, now],
    );
  }

  Future<void> toggleComparisonCheckin({
    required String traitId,
    required DateTime date,
  }) async {
    final checked = await isComparisonCheckedIn(traitId, date);
    await setComparisonCheckin(
      traitId: traitId,
      date: date,
      recorded: !checked,
    );
  }

  /// Measured value for a trait inside [window]. Returns null when the source
  /// has no eligible evidence, which the domain reports as unknown.
  Future<double?> measureComparisonTrait(
    Map<String, Object?> trait,
    DateRange window,
  ) async {
    final measurement = traitMeasurementFromStorage(
      trait['measurement_type'] as String,
    );
    final start = Variable.withString(dateKey(window.start));
    final end = Variable.withString(dateKey(window.end));
    switch (measurement) {
      case TraitMeasurement.manualCheckin:
        final result = await rows(
          'SELECT COUNT(*) AS n FROM comparison_checkins WHERE trait_id=? AND checkin_date>=? AND checkin_date<=?',
          [Variable.withString(trait['id'] as String), start, end],
        );
        final count = (result.first['n'] as num?)?.toInt() ?? 0;
        return count == 0 ? null : count.toDouble();
      case TraitMeasurement.habitQuantity:
        final habitId = trait['source_id'] as String?;
        if (habitId == null || habitId.isEmpty) return null;
        final result = await rows(
          '''SELECT COUNT(*) AS n, COALESCE(SUM(quantity),0) AS total
          FROM habit_logs WHERE habit_id=? AND log_date>=? AND log_date<=?''',
          [Variable.withString(habitId), start, end],
        );
        final count = (result.first['n'] as num?)?.toInt() ?? 0;
        if (count == 0) return null;
        return (result.first['total'] as num?)?.toDouble() ?? 0;
      case TraitMeasurement.studyMinutes:
        final subjectId = (trait['source_id'] as String?)?.trim() ?? '';
        final hasSubject = subjectId.isNotEmpty;
        final subjectFilter = hasSubject ? ' AND subject_id=?' : '';
        final variables = <Variable<Object>>[
          start,
          end,
          if (hasSubject) Variable.withString(subjectId),
        ];
        final result = await rows(
          '''SELECT COUNT(*) AS n, COALESCE(SUM(duration_minutes),0) AS total
          FROM study_sessions WHERE session_date>=? AND session_date<=?$subjectFilter''',
          variables,
        );
        final count = (result.first['n'] as num?)?.toInt() ?? 0;
        if (count == 0) return null;
        return (result.first['total'] as num?)?.toDouble() ?? 0;
    }
  }

  /// Sources a record-based trait may read. Read-only: this module never writes
  /// habit or study records.
  Future<List<Map<String, Object?>>> getComparisonSources(
    TraitMeasurement measurement,
  ) {
    return switch (measurement) {
      TraitMeasurement.manualCheckin => Future.value(const []),
      TraitMeasurement.habitQuantity => rows(
        'SELECT id, name FROM habits WHERE is_active=1 ORDER BY name COLLATE NOCASE',
      ),
      TraitMeasurement.studyMinutes => rows(
        'SELECT id, name FROM study_subjects WHERE is_active=1 ORDER BY name COLLATE NOCASE',
      ),
    };
  }

  /// Read-only projection for the Home. It evaluates active traits over the
  /// same windows used by the comparison screen and never seeds or mutates data.
  Future<ComparisonDigest> getComparisonDigest({DateTime? today}) async {
    final day = today ?? DateTime.now();
    final period = await getComparisonPeriod();
    final window = resolveComparisonWindow(
      traitWindowDays: 0,
      selected: period,
      today: day,
    );
    final traits = await getComparisonTraits();
    final evaluations = <TraitEvaluation>[];
    for (final trait in traits) {
      if ((trait['is_active'] as num?)?.toInt() != 1) continue;
      final rule = TraitRule(
        side: comparisonSideFromStorage(trait['target_character'] as String),
        measurement: traitMeasurementFromStorage(
          trait['measurement_type'] as String,
        ),
        threshold: (trait['threshold'] as num).toDouble(),
        weight: (trait['weight'] as num?)?.toDouble() ?? 1,
        windowDays: (trait['window_days'] as num?)?.toInt() ?? 0,
      );
      final traitWindow = resolveComparisonWindow(
        traitWindowDays: rule.windowDays,
        selected: period,
        today: day,
      );
      final measured = await measureComparisonTrait(trait, traitWindow);
      evaluations.add(
        evaluateTrait(
          traitId: trait['id'] as String,
          rule: rule,
          measuredValue: measured,
          window: traitWindow,
        ),
      );
    }
    final profiles = await getComparisonProfiles();
    String name(String role, String fallback) {
      final value = (profiles[role]?['display_name'] as String?)?.trim();
      return value == null || value.isEmpty ? fallback : value;
    }

    return ComparisonDigest(
      period: period,
      window: window,
      summary: summarizeComparison(evaluations),
      alfredoName: name('alfredo', 'Alfredo'),
      betoName: name('beto', 'Beto'),
    );
  }

  Future<ComparisonPeriod> getComparisonPeriod() async =>
      comparisonPeriodFromStorage(await getSetting(comparisonPeriodSettingKey));

  Future<void> setComparisonPeriod(ComparisonPeriod period) => setSetting(
    comparisonPeriodSettingKey,
    comparisonPeriodStorageValue(period),
  );
}
