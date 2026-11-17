import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:orva/core/database/app_database.dart';
import 'package:orva/core/database/executions_repository.dart';
import 'package:orva/core/database/habits_repository.dart';
import 'package:orva/core/database/orva_repository.dart';
import 'package:orva/core/theme/orva_theme.dart';
import 'package:orva/features/calendar/calendar_page.dart';
import 'package:orva/features/home/home_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase database;
  late OrvaRepository repository;

  setUpAll(() async {
    await initializeDateFormatting('pt_BR');
    Intl.defaultLocale = 'pt_BR';
  });

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    repository = OrvaRepository(database);
  });

  tearDown(() async {
    await database.close();
  });

  Future<void> seedToday() async {
    final now = DateTime.now();
    final key = repository.dateKey(now);
    await repository.saveRoutineBlock(
      title: 'Foco profundo',
      category: 'Trabalho',
      startMinute: 8 * 60,
      endMinute: 9 * 60 + 30,
      blockKind: 'date',
      specificDate: key,
    );
    await repository.saveRoutineBlock(
      title: 'Almoço',
      category: 'Alimentação',
      startMinute: 12 * 60,
      endMinute: 13 * 60,
      blockKind: 'date',
      specificDate: key,
    );
    await repository.saveExecution(
      title: 'Leitura',
      category: 'Estudo',
      startedAt: DateTime(now.year, now.month, now.day, 7, 10),
      durationMinutes: 40,
      referenceDate: now,
    );
    await repository.saveChecklist(
      title: 'Rotina da manhã',
      recurrence: 'daily',
    );
    final lists = await repository.getChecklists(includeTemplates: false);
    final list = lists.firstWhere((item) => item['title'] == 'Rotina da manhã');
    await repository.addChecklistItem(
      checklistId: list['id'] as String,
      title: 'Beber água',
    );
    await repository.saveHabit(
      name: 'Leitura',
      unit: 'páginas',
      targetValue: 20,
    );
    await repository.saveGoal(
      title: 'Concluir o semestre',
      category: 'Estudo',
      progress: 62,
    );
    await repository.saveHobby(name: 'Violão', weeklyTargetMinutes: 120);
    final hobbies = await repository.getWeeklyHobbyMinutes(date: now);
    await repository.addHobbySession(
      hobbyId: hobbies.first['id'] as String,
      sessionDate: key,
      durationMinutes: 45,
    );
  }

  Future<void> pumpHome(
    WidgetTester tester, {
    required Size size,
    required ThemeData theme,
  }) async {
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(database)],
        child: MaterialApp(
          theme: theme,
          home: HomePage(onNavigate: (_) {}, refreshSignal: 0),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  for (final size in const [
    Size(390, 844),
    Size(430, 932),
    Size(768, 1024),
    Size(1440, 900),
  ]) {
    testWidgets(
      'renders seeded Home at ${size.width.toInt()}x${size.height.toInt()}',
      (tester) async {
        await seedToday();
        await pumpHome(tester, size: size, theme: buildOrvaLightTheme());
        expect(tester.takeException(), isNull);
        expect(find.text('SEU DIA'), findsOneWidget);
        expect(find.text('Foco profundo'), findsWidgets);
        expect(find.text('OCUPAÇÃO DO DIA'), findsOneWidget);
        expect(find.text('HOBBIES'), findsOneWidget);
        expect(find.text('Violão'), findsOneWidget);
        expect(find.byType(HomePage), findsOneWidget);
        // Dispose the page timer before the next test.
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }

  testWidgets('renders the open-day state without fake metrics', (
    tester,
  ) async {
    await pumpHome(
      tester,
      size: const Size(390, 844),
      theme: buildOrvaLightTheme(),
    );
    expect(tester.takeException(), isNull);
    expect(find.text('Seu dia está em aberto.'), findsOneWidget);
    expect(find.text('Planejar meu dia'), findsOneWidget);
    expect(find.text('0 de 0 tarefas concluídas'), findsNothing);
    expect(find.text('Consistência'.toUpperCase()), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('renders in dark theme without layout errors', (tester) async {
    await seedToday();
    await pumpHome(
      tester,
      size: const Size(390, 844),
      theme: buildOrvaDarkTheme(),
    );
    expect(tester.takeException(), isNull);
    expect(find.text('SEU DIA'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('quick actions expose all five entries', (tester) async {
    await seedToday();
    await pumpHome(
      tester,
      size: const Size(390, 844),
      theme: buildOrvaLightTheme(),
    );
    for (final label in const [
      'Bloco',
      'Tarefa',
      'Registro',
      'Hábito',
      'Agenda',
    ]) {
      expect(find.text(label), findsOneWidget);
    }
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('the agenda quick action opens the calendar', (tester) async {
    await seedToday();
    await pumpHome(
      tester,
      size: const Size(390, 844),
      theme: buildOrvaLightTheme(),
    );
    await tester.tap(find.text('Agenda'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byType(CalendarPage), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('checking a priority persists to the checklist record', (
    tester,
  ) async {
    await seedToday();
    // Tall surface keeps the priorities section on screen for the tap; the
    // dedicated layout tests above cover the 390x844 composition.
    await pumpHome(
      tester,
      size: const Size(390, 1500),
      theme: buildOrvaLightTheme(),
    );
    final before = await repository.getTodayOccurrenceItems(DateTime.now());
    expect(before.single['completed'], 0);

    await tester.tap(find.byType(Checkbox).first);
    await tester.pumpAndSettle();

    final after = await repository.getTodayOccurrenceItems(DateTime.now());
    expect(after.single['completed'], 1);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
