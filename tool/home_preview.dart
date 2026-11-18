// Development-only Home preview entrypoint used for visual QA in a browser.
// It seeds a small, realistic local dataset (once per day) and opens the real
// HomePage. Use `?empty=1` to inspect the adaptive empty state and
// `?theme=dark` for the dark theme. It is not part of the shipped app.
//
// Usage:
//   flutter run -d web-server --web-port 8100 -t tool/home_preview.dart
//   http://127.0.0.1:8100/
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

import 'package:orva/core/database/app_database.dart';
import 'package:orva/core/database/comparison_repository.dart';
import 'package:orva/core/database/executions_repository.dart';
import 'package:orva/core/database/habits_repository.dart';
import 'package:orva/core/database/orva_repository.dart';
import 'package:orva/core/database/study_repository.dart';
import 'package:orva/core/theme/orva_theme.dart';
import 'package:orva/features/home/home_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('pt_BR');
  Intl.defaultLocale = 'pt_BR';

  final database = AppDatabase();
  final repository = OrvaRepository(database);
  final empty = Uri.base.queryParameters['empty'] == '1';
  final dark = Uri.base.queryParameters['theme'] == 'dark';
  if (!empty) await _seed(repository, DateTime.now());

  runApp(
    ProviderScope(
      overrides: [databaseProvider.overrideWithValue(database)],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Orva — Home preview',
        theme: buildOrvaLightTheme(),
        darkTheme: buildOrvaDarkTheme(),
        themeMode: dark ? ThemeMode.dark : ThemeMode.light,
        home: HomePage(onNavigate: (_) {}, refreshSignal: 0),
      ),
    ),
  );
}

Future<void> _seed(OrvaRepository repository, DateTime now) async {
  final key = repository.dateKey(now);
  final seeded = await repository.getSetting('home_preview_seed_$key');
  if (seeded == '1') return;
  await repository.setSetting('home_preview_seed_$key', '1');
  await repository.setSetting('user_name', 'Gabriel');

  final day = DateTime(now.year, now.month, now.day);
  final nowMinute = now.hour * 60 + now.minute;

  Future<void> block(String title, String category, int start, int end) =>
      repository.saveRoutineBlock(
        title: title,
        category: category,
        startMinute: start,
        endMinute: end,
        blockKind: 'date',
        specificDate: key,
      );

  await block('Foco profundo', 'Trabalho', 8 * 60, 9 * 60 + 30);
  await block('Alinhamento de equipe', 'Trabalho', 9 * 60, 10 * 60);
  await block('Almoço', 'Alimentação', 12 * 60, 13 * 60);
  await block('Leitura dirigida', 'Estudo', 14 * 60, 15 * 60);
  await block('Treino', 'Exercício', 18 * 60, 19 * 60);
  await block('Faculdade', 'Estudo', 19 * 60 + 30, 21 * 60 + 30);
  if (nowMinute >= 9 * 60 && nowMinute < 20 * 60) {
    final start = nowMinute - 20;
    await block('Bloco em andamento', 'Trabalho', start, start + 50);
  }

  await repository.saveExecution(
    title: 'Caminhada',
    category: 'Exercício',
    startedAt: DateTime(day.year, day.month, day.day, 6, 40),
    durationMinutes: 30,
    referenceDate: day,
  );
  await repository.saveExecution(
    title: 'Revisão de anotações',
    category: 'Estudo',
    startedAt: DateTime(day.year, day.month, day.day, 7, 5),
    durationMinutes: 40,
    referenceDate: day,
  );

  await repository.saveChecklist(title: 'Rotina da manhã', recurrence: 'daily');
  final lists = await repository.getChecklists(includeTemplates: false);
  final list = lists.firstWhere((item) => item['title'] == 'Rotina da manhã');
  for (final title in [
    'Beber água antes do café',
    'Alongar por 10 minutos',
    'Revisar a agenda do dia',
    'Ler 20 páginas',
  ]) {
    await repository.addChecklistItem(
      checklistId: list['id'] as String,
      title: title,
    );
  }
  final items = await repository.getTodayOccurrenceItems(now);
  if (items.isNotEmpty) {
    await repository.setOccurrenceItemCompleted(
      items.first['id'] as String,
      true,
    );
  }

  await repository.saveGoal(
    title: 'Concluir o semestre com média acima de 8',
    category: 'Estudo',
    deadline: repository.dateKey(day.add(const Duration(days: 45))),
    progress: 62,
  );
  await repository.saveGoal(
    title: 'Treinar três vezes por semana',
    category: 'Saúde',
    deadline: repository.dateKey(day.add(const Duration(days: 21))),
    progress: 38,
  );

  await repository.saveHabit(
    name: 'Leitura',
    unit: 'páginas',
    targetValue: 20,
    category: 'Estudo',
  );
  await repository.saveHabit(
    name: 'Meditação',
    unit: 'min',
    targetValue: 10,
    category: 'Bem-estar',
    activeDays: const [1, 3, 5],
  );
  final habits = await repository.getHabits();
  for (final habit in habits) {
    final name = habit['name'];
    final isReading = name == 'Leitura';
    for (var back = 0; back < 6; back++) {
      final date = day.subtract(Duration(days: back));
      if (!isReading && date.weekday.isEven) continue;
      if (!isReading && back == 4) continue;
      await repository.logHabit(
        habitId: habit['id'] as String,
        date: date,
        quantity: isReading ? (back == 0 ? 12 : 20) : (back == 0 ? 8 : 10),
      );
    }
  }

  await repository.saveStudySubject(name: 'Cálculo II');
  final subjects = await repository.getStudySubjects();
  for (var back = 0; back < 5; back++) {
    await repository.saveStudySession(
      subjectId: subjects.first['id'] as String,
      sessionDate: day.subtract(Duration(days: back)),
      startMinute: 14 * 60,
      durationMinutes: back.isEven ? 60 : 40,
    );
  }

  for (var back = 1; back < 6; back++) {
    await repository.saveExecution(
      title: back.isEven ? 'Caminhada' : 'Leitura',
      category: back.isEven ? 'Exercício' : 'Estudo',
      startedAt: DateTime(day.year, day.month, day.day, 7, 30),
      durationMinutes: back.isEven ? 30 : 45,
      referenceDate: day.subtract(Duration(days: back)),
    );
  }

  await repository.saveHobby(
    name: 'Violão',
    category: 'Música',
    weeklyTargetMinutes: 180,
  );
  await repository.saveHobby(
    name: 'Xadrez',
    category: 'Estratégia',
    weeklyTargetMinutes: 120,
  );
  final hobbies = await repository.getHobbies();
  final guitar = hobbies.firstWhere((item) => item['name'] == 'Violão');
  final chess = hobbies.firstWhere((item) => item['name'] == 'Xadrez');
  for (final (back, minutes) in [(0, 45), (2, 60), (4, 30)]) {
    await repository.addHobbySession(
      hobbyId: guitar['id'] as String,
      sessionDate: repository.dateKey(day.subtract(Duration(days: back))),
      durationMinutes: minutes,
    );
  }
  await repository.addHobbySession(
    hobbyId: chess['id'] as String,
    sessionDate: repository.dateKey(day.subtract(const Duration(days: 1))),
    durationMinutes: 75,
  );

  await repository.ensureComparisonSeeded();
  for (final id in ['tpl_leitura', 'tpl_treino']) {
    for (var back = 0; back < (id == 'tpl_leitura' ? 5 : 3); back++) {
      await repository.setComparisonCheckin(
        traitId: id,
        date: day.subtract(Duration(days: back)),
        recorded: true,
      );
    }
  }
}
