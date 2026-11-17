import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:orva/core/domain/calendar_layout.dart';
import 'package:orva/core/domain/comparison_scoring.dart';
import 'package:orva/core/domain/home_overview.dart';
import 'package:orva/core/domain/widget_snapshot.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('pt_BR');
  });

  CalendarEntry entry({
    required String id,
    required CalendarEntryKind kind,
    required String title,
    required int start,
    required int end,
    String category = 'Estudo',
  }) => CalendarEntry(
    id: id,
    kind: kind,
    title: title,
    category: category,
    startMinute: start,
    endMinute: end,
  );

  List<CalendarEntry> entries() => [
    entry(
      id: 'treino',
      kind: CalendarEntryKind.plannedBlock,
      title: 'Treino',
      start: 18 * 60,
      end: 19 * 60,
      category: 'Exercício',
    ),
    entry(
      id: 'faculdade',
      kind: CalendarEntryKind.plannedBlock,
      title: 'Faculdade',
      start: 19 * 60 + 30,
      end: 21 * 60 + 30,
    ),
    entry(
      id: 'leitura',
      kind: CalendarEntryKind.plannedBlock,
      title: 'Leitura',
      start: 22 * 60,
      end: 23 * 60,
      category: 'Leitura',
    ),
    entry(
      id: 'caminhada',
      kind: CalendarEntryKind.execution,
      title: 'Caminhada',
      start: 6 * 60 + 40,
      end: 7 * 60 + 10,
      category: 'Exercício',
    ),
  ];

  WidgetSnapshot populated({bool locked = false}) {
    final now = DateTime(2026, 11, 16, 19, 45);
    final report = buildHabitReport(
      habits: const [
        HabitRecord(
          id: 'h1',
          name: 'Leitura diária',
          unit: 'páginas',
          target: 20,
        ),
      ],
      logsByHabit: {
        'h1': {
          '2026-11-10': 20,
          '2026-11-11': 12,
          '2026-11-12': 0,
          '2026-11-13': 8,
          '2026-11-14': 22,
          '2026-11-15': 10,
        },
      },
      windowStart: DateTime(2026, 11, 10),
      today: DateTime(2026, 11, 16),
    );
    return buildWidgetSnapshot(
      now: now,
      locked: locked,
      overview: HomeOverview.build(entries: entries(), now: now),
      checklist: const ChecklistDigest(completed: 1, total: 4),
      checklistItems: [
        {
          'title_snapshot': 'Alongar por 10 minutos',
          'checklist_title': 'Rotina da manhã',
          'order_snapshot': 0,
          'completed': 0,
        },
        {
          'title_snapshot': 'Revisar a agenda do dia',
          'checklist_title': 'Rotina da manhã',
          'order_snapshot': 1,
          'completed': 1,
        },
        {
          'title_snapshot': 'Ler 20 páginas',
          'checklist_title': 'Estudo',
          'order_snapshot': 2,
          'completed': 0,
        },
        {
          'title_snapshot': 'Beber água',
          'checklist_title': 'Saúde',
          'order_snapshot': 3,
          'completed': 0,
        },
      ],
      goals: [
        {
          'title': 'Treinar três vezes por semana',
          'progress_value': 38,
          'deadline': '2026-12-07',
        },
        {
          'title': 'Concluir o semestre com média acima de 8',
          'progress_value': 62,
          'deadline': null,
        },
      ],
      study: const StudyDigest(
        minutes: 150,
        sessions: 3,
        reviews: 1,
        studyDays: 2,
      ),
      habits: report,
      comparison: const ComparisonSummary(
        alfredoWeight: 9,
        betoWeight: 3,
        assessedTraits: 3,
        neutralTraits: 1,
        unknownTraits: 2,
        activeTraits: 6,
      ),
      betoName: 'Beto',
      alfredoName: 'Alfredo',
    );
  }

  test('populated snapshot reflects real records', () {
    final snapshot = populated();
    expect(snapshot.locked, isFalse);
    expect(snapshot.today.headline, 'Faculdade');
    expect(snapshot.today.phaseLabel, 'Acontecendo agora');
    expect(snapshot.today.timeLabel, 'termina 21:30');
    expect(snapshot.today.checklistLabel, '1 de 4 tarefas');

    expect(snapshot.progress.plannedLabel, '4h');
    expect(snapshot.progress.executedLabel, '30min');
    expect(snapshot.progress.coveragePercent, 13);
    expect(snapshot.progress.checklistPercent, 25);
    expect(snapshot.progress.freeLabel, '20h livres');
    expect(snapshot.progress.conflictLabel, '');

    expect(snapshot.tasks.completed, 1);
    expect(snapshot.tasks.total, 4);
    expect(snapshot.tasks.items.map((task) => task.title), [
      'Alongar por 10 minutos',
      'Ler 20 páginas',
      'Beber água',
    ]);
    expect(snapshot.tasks.items.first.source, 'Rotina da manhã');

    expect(snapshot.goals.items.first.title, 'Treinar três vezes por semana');
    expect(snapshot.goals.items.first.percent, 38);
    expect(snapshot.goals.items.first.deadlineLabel, 'até 7 dez.');
    expect(snapshot.goals.items.length, 2);

    expect(snapshot.habits.percent, 71);
    expect(snapshot.habits.items.single.name, 'Leitura diária');
    expect(snapshot.habits.items.single.todayLabel, 'Pendente hoje');

    expect(snapshot.study.minutesLabel, '2h 30min');
    expect(snapshot.study.sessionsLabel, '3 sessões');

    expect(snapshot.comparison.statusLabel, 'Alfredo à frente');
    expect(snapshot.comparison.alfredoPercent, 75);
    expect(snapshot.comparison.betoPercent, 25);
    expect(snapshot.comparison.evidenceLabel, '3 de 6 critérios com evidência');

    expect(snapshot.agenda.items.first.title, 'Faculdade');
    expect(snapshot.agenda.items.first.isLive, isTrue);
    expect(snapshot.agenda.items.length, 2);
  });

  test('locked snapshot contains no user content', () {
    final snapshot = populated(locked: true);
    expect(snapshot.locked, isTrue);
    expect(snapshot.today.headline, 'Conteúdo protegido');
    expect(snapshot.tasks.items, isEmpty);
    expect(snapshot.goals.items, isEmpty);
    expect(snapshot.habits.items, isEmpty);
    expect(snapshot.agenda.items, isEmpty);
    expect(snapshot.comparison.alfredoPercent, isNull);
    final json = snapshot.toJson().toString();
    expect(json.contains('Faculdade'), isFalse);
    expect(json.contains('Alongar'), isFalse);
    expect(json.contains('Leitura diária'), isFalse);
  });

  test('empty snapshot never fabricates percentages', () {
    final snapshot = buildWidgetSnapshot(
      now: DateTime(2026, 11, 16, 8),
      locked: false,
      overview: HomeOverview.build(
        entries: const [],
        now: DateTime(2026, 11, 16, 8),
      ),
      checklist: ChecklistDigest.empty,
      checklistItems: const [],
      goals: const [],
      study: const StudyDigest(
        minutes: 0,
        sessions: 0,
        reviews: 0,
        studyDays: 0,
      ),
      habits: HabitReport.empty,
      comparison: const ComparisonSummary.empty(),
      betoName: 'Beto',
      alfredoName: 'Alfredo',
    );
    expect(snapshot.today.headline, 'Dia livre');
    expect(snapshot.today.checklistLabel, 'Nenhuma tarefa hoje');
    expect(snapshot.progress.coveragePercent, isNull);
    expect(snapshot.progress.checklistPercent, isNull);
    expect(snapshot.habits.percent, isNull);
    expect(snapshot.comparison.statusLabel, 'Sem critérios ativos');
    expect(snapshot.agenda.items, isEmpty);
  });

  test('long and multiline titles are bounded and flattened', () {
    final snapshot = buildWidgetSnapshot(
      now: DateTime(2026, 11, 16, 8),
      locked: false,
      overview: HomeOverview.build(
        entries: [
          entry(
            id: 'x',
            kind: CalendarEntryKind.plannedBlock,
            title: 'Uma atividade com\nquebra de linha e um título absurdamente longo para caber',
            start: 9 * 60,
            end: 10 * 60,
          ),
        ],
        now: DateTime(2026, 11, 16, 8),
      ),
      checklist: ChecklistDigest.empty,
      checklistItems: const [],
      goals: const [],
      study: const StudyDigest(
        minutes: 0,
        sessions: 0,
        reviews: 0,
        studyDays: 0,
      ),
      habits: HabitReport.empty,
      comparison: const ComparisonSummary.empty(),
      betoName: 'Beto',
      alfredoName: 'Alfredo',
    );
    expect(snapshot.today.headline.contains('\n'), isFalse);
    expect(snapshot.today.headline.length, lessThanOrEqualTo(48));
    expect(snapshot.today.headline.endsWith('…'), isTrue);
  });

  test('snapshot schema is versioned and carries a timestamp', () {
    final json = populated().toJson();
    expect(json['schemaVersion'], widgetSnapshotSchemaVersion);
    expect(json['generatedAtMillis'], isA<int>());
    expect(
      json.keys,
      containsAll(['today', 'progress', 'tasks', 'comparison']),
    );
    expect(json.toString().toLowerCase().contains('note'), isFalse);
    expect(json.toString().toLowerCase().contains('journal'), isFalse);
  });
}
