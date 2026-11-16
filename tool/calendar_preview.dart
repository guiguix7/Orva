// Development-only preview entrypoint used for visual QA in a browser.
// It seeds a few sample routine blocks (only when the local database is empty)
// and opens the real CalendarPage. It is not part of the shipped app.
//
// Usage:
//   flutter run -d web-server --web-port 8100 -t tool/calendar_preview.dart
//   http://127.0.0.1:8100/?view=day|week|month
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

import 'package:orva/core/database/app_database.dart';
import 'package:orva/core/database/executions_repository.dart';
import 'package:orva/core/database/orva_repository.dart';
import 'package:orva/core/theme/orva_theme.dart';
import 'package:orva/features/calendar/calendar_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('pt_BR');
  Intl.defaultLocale = 'pt_BR';

  final database = AppDatabase();
  final repository = OrvaRepository(database);
  final dateParam = DateTime.tryParse(Uri.base.queryParameters['date'] ?? '');
  final previewDate = dateParam ?? DateTime.now();
  await _seedFor(
    repository,
    DateTime(previewDate.year, previewDate.month, previewDate.day),
  );

  final view = switch (Uri.base.queryParameters['view']) {
    'week' => CalendarViewMode.week,
    'month' => CalendarViewMode.month,
    _ => CalendarViewMode.day,
  };

  runApp(
    ProviderScope(
      overrides: [databaseProvider.overrideWithValue(database)],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Orva preview',
        theme: buildOrvaLightTheme(),
        darkTheme: buildOrvaDarkTheme(),
        home: CalendarPage(initialMode: view, initialDate: previewDate),
      ),
    ),
  );
}

Future<void> _seedFor(OrvaRepository repository, DateTime today) async {
  final key = repository.dateKey(today);
  final seeded = await repository.getSetting('preview_seed_$key');
  if (seeded == '1') return;
  await repository.setSetting('preview_seed_$key', '1');

  Future<void> block(String title, String category, int start, int end) =>
      repository.saveRoutineBlock(
        title: title,
        category: category,
        startMinute: start,
        endMinute: end,
        blockKind: 'date',
        specificDate: key,
      );

  await block('Foco profundo', 'Trabalho', 8 * 60, 10 * 60);
  await block('Reunião de equipe', 'Trabalho', 9 * 60 + 30, 10 * 60 + 30);
  await block('Almoço', 'Alimentação', 12 * 60, 13 * 60);
  await block('Treino', 'Exercício', 18 * 60, 19 * 60);
  await block('Faculdade', 'Estudo', 19 * 60, 22 * 60);

  await repository.saveExecution(
    title: 'Leitura',
    category: 'Estudo',
    startedAt: DateTime(today.year, today.month, today.day, 14, 10),
    durationMinutes: 45,
    referenceDate: today,
  );
}
