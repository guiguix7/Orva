import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/calendar_repository.dart';
import '../database/comparison_repository.dart';
import '../database/habits_repository.dart';
import '../database/orva_repository.dart';
import '../database/study_repository.dart';
import '../domain/calendar_layout.dart';
import '../domain/comparison_scoring.dart';
import '../domain/home_overview.dart';
import '../domain/widget_snapshot.dart';
import '../logging/orva_diagnostics.dart';
import 'widget_bridge.dart';

/// Loads the same projections the Home screen uses, then publishes a sanitized
/// snapshot for the Android widgets.
///
/// Triggers are owned by the app shell (launch, resume, pause and a slow
/// foreground timer). Widgets honestly show the last snapshot time; no
/// background Dart isolate or direct database access is required.
class WidgetSyncService {
  WidgetSyncService(this._ref);

  final WidgetRef _ref;
  bool _running = false;

  Future<void> refresh() async {
    if (!OrvaWidgetBridge.isSupported || _running) return;
    _running = true;
    try {
      final repo = _ref.read(repositoryProvider);
      final now = DateTime.now();

      // Widgets stay visible on the lock screen. When the app is protected,
      // publish content-free state instead of blurring the data.
      if (await repo.isLockEnabled()) {
        await OrvaWidgetBridge.saveSnapshot(WidgetSnapshot.protected(now));
        return;
      }

      final day = DateTime(now.year, now.month, now.day);
      final weekStart = DateTime(
        day.year,
        day.month,
        day.day - (day.weekday - 1),
      );
      final habitWindowStart = DateTime(day.year, day.month, day.day - 6);

      final habitRows = await repo.getHabits();
      final habitRecords = <HabitRecord>[];
      final logsByHabit = <String, Map<String, double>>{};
      for (final row in habitRows) {
        final id = row['id'] as String;
        habitRecords.add(
          HabitRecord(
            id: id,
            name: (row['name'] as String?)?.trim().isNotEmpty == true
                ? row['name'] as String
                : 'Hábito',
            unit: (row['unit'] as String?)?.trim().isNotEmpty == true
                ? row['unit'] as String
                : 'vezes',
            target: (row['target_value'] as num?)?.toDouble(),
            activeWeekdays: _parseActiveDays(row['active_days_json']),
          ),
        );
        final logRows = await repo.getHabitLogs(
          id,
          from: habitWindowStart,
          to: day,
        );
        logsByHabit[id] = {
          for (final log in logRows)
            if (log['log_date'] is String)
              log['log_date'] as String:
                  (log['quantity'] as num?)?.toDouble() ?? 0,
        };
      }

      final values = await Future.wait<Object?>([
        repo.loadCalendarEntries(day),
        repo.getTodayOccurrenceItems(day),
        repo.getGoals(status: 'active'),
        repo.getStudySummary(from: weekStart, to: day),
        repo.getComparisonPeriod(),
        repo.getComparisonProfiles(),
        repo.getComparisonTraits(),
      ]);

      final entries = values[0] as List<CalendarEntry>;
      final items = values[1] as List<Map<String, Object?>>;
      final completed = items
          .where((item) => (item['completed'] as num?)?.toInt() == 1)
          .length;
      final studyRow = values[3] as Map<String, Object?>;
      final period = values[4] as ComparisonPeriod;
      final profiles = values[5] as Map<String, Map<String, Object?>>;
      final traits = values[6] as List<Map<String, Object?>>;

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
        final window = resolveComparisonWindow(
          traitWindowDays: rule.windowDays,
          selected: period,
          today: now,
        );
        final measured = await repo.measureComparisonTrait(trait, window);
        evaluations.add(
          evaluateTrait(
            traitId: trait['id'] as String,
            rule: rule,
            measuredValue: measured,
            window: window,
          ),
        );
      }
      final summary = summarizeComparison(evaluations);

      final report = buildHabitReport(
        habits: habitRecords,
        logsByHabit: logsByHabit,
        windowStart: habitWindowStart,
        today: day,
      );

      final snapshot = buildWidgetSnapshot(
        now: now,
        locked: false,
        overview: HomeOverview.build(entries: entries, now: now),
        checklist: ChecklistDigest(completed: completed, total: items.length),
        checklistItems: items,
        goals: values[2] as List<Map<String, Object?>>,
        study: StudyDigest(
          minutes: (studyRow['minutes'] as num?)?.toInt() ?? 0,
          sessions: (studyRow['sessions'] as num?)?.toInt() ?? 0,
          reviews: (studyRow['reviews'] as num?)?.toInt() ?? 0,
          studyDays: (studyRow['studyDays'] as num?)?.toInt() ?? 0,
        ),
        habits: report,
        comparison: summary,
        betoName: _profileName(profiles, 'beto', 'Beto'),
        alfredoName: _profileName(profiles, 'alfredo', 'Alfredo'),
      );
      await OrvaWidgetBridge.saveSnapshot(snapshot);
    } catch (error, stackTrace) {
      // A widget refresh must never interrupt the app; widgets keep their
      // previous (timestamped) snapshot and report staleness honestly.
      OrvaDiagnostics.instance.recordException(
        error,
        stackTrace,
        category: 'widget-snapshot',
        module: 'home-widgets',
        severity: DiagnosticSeverity.warning,
      );
    } finally {
      _running = false;
    }
  }
}

String _profileName(
  Map<String, Map<String, Object?>> profiles,
  String role,
  String fallback,
) {
  final name = (profiles[role]?['display_name'] as String?)?.trim();
  return name == null || name.isEmpty ? fallback : name;
}

Set<int> _parseActiveDays(Object? raw) {
  if (raw is! String || raw.isEmpty) return const {};
  final days = <int>{};
  for (final match in RegExp(r'\d').allMatches(raw)) {
    final day = int.tryParse(match.group(0)!);
    if (day != null && day >= 1 && day <= 7) days.add(day);
  }
  return days;
}
