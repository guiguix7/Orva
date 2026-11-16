/// Pure comparison logic for the fixed Beto/Alfredo pair.
///
/// No database, clock or platform access: callers resolve the period and
/// measurements, then pass explicit values. The rules here are the only place
/// that decides an outcome, so they can be unit-tested deterministically.
library;

/// The two built-in identities. The pair is fixed by product decision; only
/// presentation and trait rules can be personalized.
enum ComparisonSide { beto, alfredo }

/// How a trait obtains evidence.
enum TraitMeasurement {
  /// Explicit user check-in, one record per local day.
  manualCheckin,

  /// Quantity logged in an existing Orva habit.
  habitQuantity,

  /// Minutes registered in existing Orva study sessions.
  studyMinutes,
}

String traitMeasurementStorageValue(TraitMeasurement measurement) =>
    switch (measurement) {
      TraitMeasurement.manualCheckin => 'manual',
      TraitMeasurement.habitQuantity => 'habit_quantity',
      TraitMeasurement.studyMinutes => 'study_minutes',
    };

TraitMeasurement traitMeasurementFromStorage(String value) => switch (value) {
  'manual' => TraitMeasurement.manualCheckin,
  'habit_quantity' => TraitMeasurement.habitQuantity,
  'study_minutes' => TraitMeasurement.studyMinutes,
  _ => throw ArgumentError('Tipo de medição desconhecido: $value'),
};

String comparisonSideStorageValue(ComparisonSide side) => switch (side) {
  ComparisonSide.beto => 'beto',
  ComparisonSide.alfredo => 'alfredo',
};

ComparisonSide comparisonSideFromStorage(String value) => switch (value) {
  'beto' => ComparisonSide.beto,
  'alfredo' => ComparisonSide.alfredo,
  _ => throw ArgumentError('Personagem desconhecido: $value'),
};

/// One measurable behavior and the side it favors when its threshold is met.
final class TraitRule {
  TraitRule({
    required this.side,
    required this.measurement,
    required this.threshold,
    this.weight = 1,
    this.windowDays = 0,
  }) {
    if (!threshold.isFinite || threshold <= 0) {
      throw ArgumentError.value(
        threshold,
        'threshold',
        'O limiar deve ser maior que zero.',
      );
    }
    if (!weight.isFinite || weight <= 0) {
      throw ArgumentError.value(
        weight,
        'weight',
        'O peso deve ser maior que zero.',
      );
    }
    if (windowDays < 0 || windowDays > 365) {
      throw ArgumentError.value(
        windowDays,
        'windowDays',
        'A janela deve estar entre 0 e 365 dias.',
      );
    }
  }

  /// Side this trait favors when the threshold is reached.
  final ComparisonSide side;
  final TraitMeasurement measurement;
  final double threshold;
  final double weight;

  /// 0 means "follow the period selected in the comparison screen".
  final int windowDays;
}

/// Inclusive local-date interval. Date-only values, never UTC timestamps.
final class DateRange {
  DateRange(this.start, this.end) {
    if (end.isBefore(start)) {
      throw ArgumentError('O fim do período não pode ser anterior ao início.');
    }
  }

  final DateTime start;
  final DateTime end;

  /// Number of local calendar days, computed on UTC-normalized dates so DST
  /// shifts in a local zone cannot change the count.
  int get days =>
      DateTime.utc(
        end.year,
        end.month,
        end.day,
      ).difference(DateTime.utc(start.year, start.month, start.day)).inDays +
      1;

  bool includes(DateTime date) {
    final day = DateTime(date.year, date.month, date.day);
    return !day.isBefore(DateTime(start.year, start.month, start.day)) &&
        !day.isAfter(DateTime(end.year, end.month, end.day));
  }
}

enum ComparisonPeriod { last7Days, last30Days, currentWeek, currentMonth }

String comparisonPeriodStorageValue(ComparisonPeriod period) =>
    switch (period) {
      ComparisonPeriod.last7Days => 'last7',
      ComparisonPeriod.last30Days => 'last30',
      ComparisonPeriod.currentWeek => 'week',
      ComparisonPeriod.currentMonth => 'month',
    };

ComparisonPeriod comparisonPeriodFromStorage(String? value) => switch (value) {
  'last7' => ComparisonPeriod.last7Days,
  'week' => ComparisonPeriod.currentWeek,
  'month' => ComparisonPeriod.currentMonth,
  _ => ComparisonPeriod.last30Days,
};

/// Resolves the window a single trait is evaluated over. A trait-level window
/// takes precedence over the screen selection; week boundaries start on Monday.
DateRange resolveComparisonWindow({
  required int traitWindowDays,
  required ComparisonPeriod selected,
  required DateTime today,
}) {
  final day = DateTime(today.year, today.month, today.day);
  if (traitWindowDays > 0) {
    return DateRange(
      DateTime(day.year, day.month, day.day - (traitWindowDays - 1)),
      day,
    );
  }
  return switch (selected) {
    ComparisonPeriod.last7Days => DateRange(
      DateTime(day.year, day.month, day.day - 6),
      day,
    ),
    ComparisonPeriod.last30Days => DateRange(
      DateTime(day.year, day.month, day.day - 29),
      day,
    ),
    ComparisonPeriod.currentWeek => DateRange(
      DateTime(day.year, day.month, day.day - (day.weekday - 1)),
      day,
    ),
    ComparisonPeriod.currentMonth => DateRange(
      DateTime(day.year, day.month, 1),
      day,
    ),
  };
}

enum TraitOutcome {
  favorsAlfredo,
  favorsBeto,

  /// Evidence exists but did not reach the rule threshold.
  neutral,

  /// No eligible evidence in the window. Never assigned to either side.
  unknown,
}

/// Result of evaluating one trait over its window.
final class TraitEvaluation {
  const TraitEvaluation({
    required this.traitId,
    required this.side,
    required this.outcome,
    required this.weight,
    required this.measuredValue,
    required this.threshold,
    required this.measurement,
    required this.window,
  });

  final String traitId;
  final ComparisonSide side;
  final TraitOutcome outcome;
  final double weight;
  final double? measuredValue;
  final double threshold;
  final TraitMeasurement measurement;
  final DateRange window;
}

/// Evaluates a trait. `measuredValue` is null when the source produced no
/// eligible evidence in the window; absence of a log never proves the behavior
/// did not happen, so it is reported as unknown instead of a point to a side.
TraitEvaluation evaluateTrait({
  required String traitId,
  required TraitRule rule,
  required double? measuredValue,
  required DateRange window,
}) {
  if (measuredValue != null && (!measuredValue.isFinite || measuredValue < 0)) {
    throw ArgumentError.value(
      measuredValue,
      'measuredValue',
      'Valor medido inválido.',
    );
  }
  final outcome = switch (measuredValue) {
    null => TraitOutcome.unknown,
    final value when value >= rule.threshold =>
      rule.side == ComparisonSide.alfredo
          ? TraitOutcome.favorsAlfredo
          : TraitOutcome.favorsBeto,
    _ => TraitOutcome.neutral,
  };
  return TraitEvaluation(
    traitId: traitId,
    side: rule.side,
    outcome: outcome,
    weight: rule.weight,
    measuredValue: measuredValue,
    threshold: rule.threshold,
    measurement: rule.measurement,
    window: window,
  );
}

/// Weighted result for the active traits. Unknown and neutral traits carry no
/// evidence for either side and are excluded from the denominator.
final class ComparisonSummary {
  const ComparisonSummary({
    required this.alfredoWeight,
    required this.betoWeight,
    required this.assessedTraits,
    required this.neutralTraits,
    required this.unknownTraits,
    required this.activeTraits,
  });

  const ComparisonSummary.empty()
    : alfredoWeight = 0,
      betoWeight = 0,
      assessedTraits = 0,
      neutralTraits = 0,
      unknownTraits = 0,
      activeTraits = 0;

  final double alfredoWeight;
  final double betoWeight;
  final int assessedTraits;
  final int neutralTraits;
  final int unknownTraits;
  final int activeTraits;

  double get assessedWeight => alfredoWeight + betoWeight;

  bool get hasEvidence => assessedWeight > 0;

  double? get alfredoShare =>
      hasEvidence ? alfredoWeight / assessedWeight : null;

  double? get betoShare => hasEvidence ? betoWeight / assessedWeight : null;

  double get coverage => activeTraits == 0 ? 0 : assessedTraits / activeTraits;
}

ComparisonSummary summarizeComparison(Iterable<TraitEvaluation> evaluations) {
  var alfredo = 0.0;
  var beto = 0.0;
  var assessed = 0;
  var neutral = 0;
  var unknown = 0;
  var active = 0;
  for (final evaluation in evaluations) {
    active++;
    switch (evaluation.outcome) {
      case TraitOutcome.favorsAlfredo:
        alfredo += evaluation.weight;
        assessed++;
      case TraitOutcome.favorsBeto:
        beto += evaluation.weight;
        assessed++;
      case TraitOutcome.neutral:
        neutral++;
      case TraitOutcome.unknown:
        unknown++;
    }
  }
  return ComparisonSummary(
    alfredoWeight: alfredo,
    betoWeight: beto,
    assessedTraits: assessed,
    neutralTraits: neutral,
    unknownTraits: unknown,
    activeTraits: active,
  );
}
