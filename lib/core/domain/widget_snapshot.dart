/// Versioned, sanitized projection of Orva records for Android home-screen
/// widgets.
///
/// The database remains authoritative: this module only rearranges facts the
/// repositories already produced. It never invents progress, never reads
/// journal/notes/finance/health tables and never exposes stored notes.
///
/// Widgets can be visible while the phone is locked. When the app lock is on,
/// [buildWidgetSnapshot] returns a protected snapshot without any user content,
/// so a native rendering bug cannot leak titles, habits or comparison names.
library;

import 'package:intl/intl.dart';

import 'calendar_layout.dart';
import 'comparison_scoring.dart';
import 'home_overview.dart';

const widgetSnapshotSchemaVersion = 1;

/// Maximum rows a widget may receive. Keeps RemoteViews small and readable.
const _maxTasks = 4;
const _maxGoals = 3;
const _maxHabits = 4;
const _maxAgenda = 3;

final class WidgetSnapshot {
  const WidgetSnapshot({
    required this.generatedAt,
    required this.dateLabel,
    required this.locked,
    required this.today,
    required this.progress,
    required this.tasks,
    required this.comparison,
    required this.goals,
    required this.habits,
    required this.study,
    required this.agenda,
  });

  /// Content-free state for lock screens and first run.
  factory WidgetSnapshot.protected(DateTime now) => WidgetSnapshot(
    generatedAt: now,
    dateLabel: _dateLabel(now),
    locked: true,
    today: const WidgetToday(
      phaseLabel: 'Orva',
      headline: 'Conteúdo protegido',
      detail: 'Abra o Orva para desbloquear.',
      timeLabel: '',
      checklistLabel: '',
    ),
    progress: const WidgetProgress.empty(),
    tasks: const WidgetTaskList(),
    comparison: const WidgetComparison.empty(),
    goals: const WidgetGoalList(),
    habits: const WidgetHabitList(),
    study: const WidgetStudy.empty(),
    agenda: const WidgetAgendaList(),
  );

  factory WidgetSnapshot.empty(DateTime now) => WidgetSnapshot(
    generatedAt: now,
    dateLabel: _dateLabel(now),
    locked: false,
    today: const WidgetToday(
      phaseLabel: 'Hoje',
      headline: 'Abra o Orva',
      detail: 'Seu dia aparece aqui depois da primeira atualização.',
      timeLabel: '',
      checklistLabel: '',
    ),
    progress: const WidgetProgress.empty(),
    tasks: const WidgetTaskList(),
    comparison: const WidgetComparison.empty(),
    goals: const WidgetGoalList(),
    habits: const WidgetHabitList(),
    study: const WidgetStudy.empty(),
    agenda: const WidgetAgendaList(),
  );

  final DateTime generatedAt;
  final String dateLabel;
  final bool locked;
  final WidgetToday today;
  final WidgetProgress progress;
  final WidgetTaskList tasks;
  final WidgetComparison comparison;
  final WidgetGoalList goals;
  final WidgetHabitList habits;
  final WidgetStudy study;
  final WidgetAgendaList agenda;

  Map<String, Object?> toJson() => {
    'schemaVersion': widgetSnapshotSchemaVersion,
    'generatedAtMillis': generatedAt.millisecondsSinceEpoch,
    'dateLabel': dateLabel,
    'locked': locked,
    'today': today.toJson(),
    'progress': progress.toJson(),
    'tasks': tasks.toJson(),
    'comparison': comparison.toJson(),
    'goals': goals.toJson(),
    'habits': habits.toJson(),
    'study': study.toJson(),
    'agenda': agenda.toJson(),
  };
}

final class WidgetToday {
  const WidgetToday({
    required this.phaseLabel,
    required this.headline,
    required this.detail,
    required this.timeLabel,
    required this.checklistLabel,
  });

  final String phaseLabel;
  final String headline;
  final String detail;
  final String timeLabel;
  final String checklistLabel;

  Map<String, Object?> toJson() => {
    'phaseLabel': phaseLabel,
    'headline': headline,
    'detail': detail,
    'timeLabel': timeLabel,
    'checklistLabel': checklistLabel,
  };
}

final class WidgetProgress {
  const WidgetProgress({
    required this.plannedLabel,
    required this.executedLabel,
    required this.coveragePercent,
    required this.checklistPercent,
    required this.freeLabel,
    required this.conflictLabel,
  });

  const WidgetProgress.empty()
    : plannedLabel = '—',
      executedLabel = '—',
      coveragePercent = null,
      checklistPercent = null,
      freeLabel = '',
      conflictLabel = '';

  final String plannedLabel;
  final String executedLabel;

  /// Executed minutes divided by planned minutes. Null when nothing planned.
  final int? coveragePercent;
  final int? checklistPercent;
  final String freeLabel;
  final String conflictLabel;

  Map<String, Object?> toJson() => {
    'plannedLabel': plannedLabel,
    'executedLabel': executedLabel,
    'coveragePercent': coveragePercent,
    'checklistPercent': checklistPercent,
    'freeLabel': freeLabel,
    'conflictLabel': conflictLabel,
  };
}

final class WidgetTask {
  const WidgetTask({required this.title, required this.source});

  final String title;
  final String source;

  Map<String, Object?> toJson() => {'title': title, 'source': source};
}

final class WidgetTaskList {
  const WidgetTaskList({
    this.completed = 0,
    this.total = 0,
    this.items = const [],
  });

  final int completed;
  final int total;
  final List<WidgetTask> items;

  bool get isEmpty => total == 0;

  Map<String, Object?> toJson() => {
    'completed': completed,
    'total': total,
    'items': [for (final item in items) item.toJson()],
  };
}

final class WidgetComparison {
  const WidgetComparison({
    required this.alfredoName,
    required this.betoName,
    required this.alfredoPercent,
    required this.betoPercent,
    required this.statusLabel,
    required this.evidenceLabel,
  });

  const WidgetComparison.empty()
    : alfredoName = 'Alfredo',
      betoName = 'Beto',
      alfredoPercent = null,
      betoPercent = null,
      statusLabel = 'Sem comparação',
      evidenceLabel = 'Abra o Orva para começar.';

  final String alfredoName;
  final String betoName;

  /// Weighted share of assessed traits, or null when there is no evidence.
  final int? alfredoPercent;
  final int? betoPercent;
  final String statusLabel;
  final String evidenceLabel;

  Map<String, Object?> toJson() => {
    'alfredoName': alfredoName,
    'betoName': betoName,
    'alfredoPercent': alfredoPercent,
    'betoPercent': betoPercent,
    'statusLabel': statusLabel,
    'evidenceLabel': evidenceLabel,
  };
}

final class WidgetGoal {
  const WidgetGoal({
    required this.title,
    required this.percent,
    required this.deadlineLabel,
  });

  final String title;
  final int percent;
  final String deadlineLabel;

  Map<String, Object?> toJson() => {
    'title': title,
    'percent': percent,
    'deadlineLabel': deadlineLabel,
  };
}

final class WidgetGoalList {
  const WidgetGoalList({this.items = const [], this.summary = ''});

  final List<WidgetGoal> items;
  final String summary;

  Map<String, Object?> toJson() => {
    'summary': summary,
    'items': [for (final item in items) item.toJson()],
  };
}

final class WidgetHabit {
  const WidgetHabit({
    required this.name,
    required this.todayLabel,
    required this.consistencyPercent,
  });

  final String name;
  final String todayLabel;
  final int? consistencyPercent;

  Map<String, Object?> toJson() => {
    'name': name,
    'todayLabel': todayLabel,
    'consistencyPercent': consistencyPercent,
  };
}

final class WidgetHabitList {
  const WidgetHabitList({
    this.items = const [],
    this.summary = '',
    this.percent,
  });

  final List<WidgetHabit> items;
  final String summary;
  final int? percent;

  Map<String, Object?> toJson() => {
    'summary': summary,
    'percent': percent,
    'items': [for (final item in items) item.toJson()],
  };
}

final class WidgetStudy {
  const WidgetStudy({
    required this.minutesLabel,
    required this.sessionsLabel,
    required this.reviewsLabel,
    required this.daysLabel,
    required this.summary,
  });

  const WidgetStudy.empty()
    : minutesLabel = '0min',
      sessionsLabel = '0 sessões',
      reviewsLabel = '0 revisões',
      daysLabel = '0 dias',
      summary = 'Nenhuma sessão nesta semana.';

  final String minutesLabel;
  final String sessionsLabel;
  final String reviewsLabel;
  final String daysLabel;
  final String summary;

  Map<String, Object?> toJson() => {
    'minutesLabel': minutesLabel,
    'sessionsLabel': sessionsLabel,
    'reviewsLabel': reviewsLabel,
    'daysLabel': daysLabel,
    'summary': summary,
  };
}

final class WidgetAgendaItem {
  const WidgetAgendaItem({
    required this.timeLabel,
    required this.title,
    required this.subtitle,
    required this.isLive,
  });

  final String timeLabel;
  final String title;
  final String subtitle;
  final bool isLive;

  Map<String, Object?> toJson() => {
    'timeLabel': timeLabel,
    'title': title,
    'subtitle': subtitle,
    'isLive': isLive,
  };
}

final class WidgetAgendaList {
  const WidgetAgendaList({this.items = const [], this.summary = ''});

  final List<WidgetAgendaItem> items;
  final String summary;

  Map<String, Object?> toJson() => {
    'summary': summary,
    'items': [for (final item in items) item.toJson()],
  };
}

/// Builds the sanitized snapshot from already-loaded projections.
///
/// [comparison] must be the same summary the comparison screen shows; no new
/// scoring rule is introduced here. [locked] short-circuits all content.
WidgetSnapshot buildWidgetSnapshot({
  required DateTime now,
  required bool locked,
  required HomeOverview overview,
  required ChecklistDigest checklist,
  required List<Map<String, Object?>> checklistItems,
  required List<Map<String, Object?>> goals,
  required StudyDigest study,
  required HabitReport habits,
  required ComparisonSummary comparison,
  required String betoName,
  required String alfredoName,
}) {
  if (locked) return WidgetSnapshot.protected(now);

  final live = overview.liveActivity;
  final next = overview.nextActivity;
  final focus = live ?? next;
  final today = WidgetToday(
    phaseLabel: live != null
        ? 'Acontecendo agora'
        : (next != null ? 'Próximo' : 'Hoje'),
    headline: focus == null ? 'Dia livre' : _clean(focus.title, 48),
    detail: focus == null
        ? 'Nenhum bloco planejado para hoje.'
        : [
            _clean(focus.category, 24),
            _clean(
              focus.kind == CalendarEntryKind.obligation ? 'compromisso' : '',
              24,
            ),
          ].where((value) => value.isNotEmpty).join(' · '),
    timeLabel: focus == null
        ? ''
        : live != null
        ? 'termina ${_clock(focus.endMinute)}'
        : '${_clock(focus.startMinute)}–${_clock(focus.endMinute)}',
    checklistLabel: checklist.total == 0
        ? 'Nenhuma tarefa hoje'
        : '${checklist.completed} de ${checklist.total} tarefas',
  );

  final pendingTasks =
      checklistItems
          .where((item) => (item['completed'] as num?)?.toInt() != 1)
          .toList()
        ..sort(
          (a, b) => ((a['order_snapshot'] as num?) ?? 0).compareTo(
            (b['order_snapshot'] as num?) ?? 0,
          ),
        );
  final taskList = WidgetTaskList(
    completed: checklist.completed,
    total: checklist.total,
    items: [
      for (final item in pendingTasks.take(_maxTasks))
        WidgetTask(
          title: _clean((item['title_snapshot'] as String?) ?? 'Tarefa', 64),
          source: _clean((item['checklist_title'] as String?) ?? '', 32),
        ),
    ],
  );

  final goalItems = goals.take(_maxGoals).toList();
  final goalList = WidgetGoalList(
    summary: goals.isEmpty
        ? 'Nenhuma meta ativa.'
        : '${goals.length} ${goals.length == 1 ? 'meta ativa' : 'metas ativas'}',
    items: [
      for (final goal in goalItems)
        WidgetGoal(
          title: _clean((goal['title'] as String?) ?? 'Meta', 52),
          percent: ((goal['progress_value'] as num?)?.toDouble() ?? 0)
              .clamp(0, 100)
              .round(),
          deadlineLabel: _deadlineLabel(goal['deadline'] as String?),
        ),
    ],
  );

  final habitSignals = habits.signals.take(_maxHabits).toList();
  final habitPercent = _percentOrNull(habits.consistency);
  final habitList = WidgetHabitList(
    percent: habitPercent,
    summary: habits.isEmpty
        ? 'Nenhum hábito ativo.'
        : habitPercent == null
        ? 'Sem oportunidades nos últimos 7 dias.'
        : '${habits.loggedDays} de ${habits.eligibleDays} oportunidades · 7 dias',
    items: [
      for (final signal in habitSignals)
        WidgetHabit(
          name: _clean(signal.habit.name, 34),
          todayLabel: !signal.isTodayEligible
              ? 'Hoje não'
              : signal.isTodayLogged
              ? 'Feito hoje'
              : 'Pendente hoje',
          consistencyPercent: _percentOrNull(signal.consistency),
        ),
    ],
  );

  final comparisonSnapshot = _comparisonSnapshot(
    comparison: comparison,
    betoName: betoName,
    alfredoName: alfredoName,
  );

  final upcoming = <WidgetAgendaItem>[];
  final planned = overview.items
      .where(
        (item) =>
            item.isPlanned &&
            (item.phase == HomeEntryPhase.live ||
                item.phase == HomeEntryPhase.upcoming),
      )
      .take(_maxAgenda);
  for (final item in planned) {
    upcoming.add(
      WidgetAgendaItem(
        timeLabel:
            '${_clock(item.entry.startMinute)}–${_clock(item.entry.endMinute)}',
        title: _clean(item.entry.title, 44),
        subtitle: _clean(
          [
            item.entry.category,
            item.phase == HomeEntryPhase.live ? 'agora' : 'planejado',
          ].where((value) => value.trim().isNotEmpty).join(' · '),
          36,
        ),
        isLive: item.phase == HomeEntryPhase.live,
      ),
    );
  }
  final agenda = WidgetAgendaList(
    items: upcoming,
    summary: upcoming.isEmpty
        ? 'Nada mais planejado para hoje.'
        : '${upcoming.length} ${upcoming.length == 1 ? 'próximo bloco' : 'próximos blocos'}',
  );

  final progress = WidgetProgress(
    plannedLabel: _duration(overview.plannedMinutes),
    executedLabel: _duration(overview.executedMinutes),
    coveragePercent: _percentOrNull(overview.executionCoverage),
    checklistPercent: _percentOrNull(checklist.ratio),
    freeLabel: '${_duration(overview.freeMinutes)} livres',
    conflictLabel: overview.conflictCount == 0
        ? ''
        : '${overview.conflictCount} ${overview.conflictCount == 1 ? 'conflito' : 'conflitos'}',
  );

  final studySnapshot = WidgetStudy(
    minutesLabel: _duration(study.minutes),
    sessionsLabel:
        '${study.sessions} ${study.sessions == 1 ? 'sessão' : 'sessões'}',
    reviewsLabel:
        '${study.reviews} ${study.reviews == 1 ? 'revisão' : 'revisões'}',
    daysLabel: '${study.studyDays} ${study.studyDays == 1 ? 'dia' : 'dias'}',
    summary: study.hasEvidence
        ? 'Semana atual · ${_duration(study.minutes)} de estudo'
        : 'Nenhuma sessão nesta semana.',
  );

  return WidgetSnapshot(
    generatedAt: now,
    dateLabel: _dateLabel(now),
    locked: false,
    today: today,
    progress: progress,
    tasks: taskList,
    comparison: comparisonSnapshot,
    goals: goalList,
    habits: habitList,
    study: studySnapshot,
    agenda: agenda,
  );
}

WidgetComparison _comparisonSnapshot({
  required ComparisonSummary comparison,
  required String betoName,
  required String alfredoName,
}) {
  final beto = _clean(betoName.isEmpty ? 'Beto' : betoName, 24);
  final alfredo = _clean(alfredoName.isEmpty ? 'Alfredo' : alfredoName, 24);
  if (comparison.activeTraits == 0) {
    return WidgetComparison(
      alfredoName: alfredo,
      betoName: beto,
      alfredoPercent: null,
      betoPercent: null,
      statusLabel: 'Sem critérios ativos',
      evidenceLabel: 'Ative critérios no Orva.',
    );
  }
  if (!comparison.hasEvidence) {
    return WidgetComparison(
      alfredoName: alfredo,
      betoName: beto,
      alfredoPercent: null,
      betoPercent: null,
      statusLabel: 'Sem evidência ainda',
      evidenceLabel:
          '${comparison.activeTraits} ${comparison.activeTraits == 1 ? 'critério ativo' : 'critérios ativos'}',
    );
  }
  final betoPercent = _percentOrNull(comparison.betoShare) ?? 0;
  final alfredoPercent = _percentOrNull(comparison.alfredoShare) ?? 0;
  final status = betoPercent > alfredoPercent
      ? '$beto à frente'
      : alfredoPercent > betoPercent
      ? '$alfredo à frente'
      : 'Equilíbrio';
  return WidgetComparison(
    alfredoName: alfredo,
    betoName: beto,
    alfredoPercent: alfredoPercent,
    betoPercent: betoPercent,
    statusLabel: status,
    evidenceLabel:
        '${comparison.assessedTraits} de ${comparison.activeTraits} critérios com evidência',
  );
}

String _dateLabel(DateTime now) {
  final label = DateFormat("EEEE, d 'de' MMMM", 'pt_BR').format(now);
  return label.isEmpty ? label : label[0].toUpperCase() + label.substring(1);
}

String _clock(int minute) {
  final safe = minute.clamp(0, 1439);
  return '${(safe ~/ 60).toString().padLeft(2, '0')}:'
      '${(safe % 60).toString().padLeft(2, '0')}';
}

String _duration(int minutes) {
  final safe = minutes < 0 ? 0 : minutes;
  if (safe < 60) return '${safe}min';
  final hours = safe ~/ 60;
  final rest = safe % 60;
  return rest == 0 ? '${hours}h' : '${hours}h ${rest}min';
}

int? _percentOrNull(double? ratio) {
  if (ratio == null || !ratio.isFinite) return null;
  return (ratio.clamp(0, 1) * 100).round();
}

String _deadlineLabel(String? raw) {
  if (raw == null || raw.trim().isEmpty) return '';
  final date = DateTime.tryParse(raw);
  if (date == null) return '';
  return 'até ${DateFormat('d MMM', 'pt_BR').format(date)}';
}

/// Keeps a single line, bounded length and no control characters. Notes are
/// never part of the snapshot; this only guards titles coming from records.
String _clean(String value, int maxLength) {
  final normalized = value
      .replaceAll(RegExp(r'[\u0000-\u001F\u007F]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  if (normalized.length <= maxLength) return normalized;
  return '${normalized.substring(0, maxLength - 1).trimRight()}…';
}
