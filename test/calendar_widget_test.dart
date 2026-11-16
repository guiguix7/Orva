import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:orva/core/domain/calendar_layout.dart';
import 'package:orva/core/theme/orva_theme.dart';
import 'package:orva/features/calendar/calendar_views.dart';

CalendarEntry _entry(String id, int start, int end, String category) =>
    CalendarEntry(
      id: id,
      kind: CalendarEntryKind.plannedBlock,
      title: id,
      category: category,
      startMinute: start,
      endMinute: end,
    );

void main() {
  setUpAll(() async {
    await initializeDateFormatting('pt_BR');
    Intl.defaultLocale = 'pt_BR';
  });

  final day = DateTime(2026, 11, 10);
  final entries = <CalendarEntry>[
    _entry('Foco profundo', 8 * 60, 10 * 60, 'Trabalho'),
    _entry('Reunião de equipe', 9 * 60 + 30, 10 * 60 + 30, 'Trabalho'),
    _entry('Almoço', 12 * 60, 13 * 60, 'Alimentação'),
  ];

  Future<void> pumpWeek(WidgetTester tester, Size size) async {
    await tester.binding.setSurfaceSize(size);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildOrvaLightTheme(),
        home: Scaffold(
          body: WeekBoard(
            byDay: {localDateKey(day): entries},
            days: weekDays(day),
            selectedDay: day,
            onSelectDay: (_) {},
            onOpenDay: (_) {},
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('week board does not overflow on desktop', (tester) async {
    await pumpWeek(tester, const Size(1440, 900));
    expect(tester.takeException(), isNull);
    expect(find.text('Foco profundo'), findsOneWidget);
  });

  testWidgets('week board does not overflow on a phone', (tester) async {
    await pumpWeek(tester, const Size(390, 844));
    expect(tester.takeException(), isNull);
    // Compact week shows a proportional strip instead of block titles.
    expect(find.text('Foco profundo'), findsNothing);
  });

  testWidgets('month grid does not overflow on a phone', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    await tester.pumpWidget(
      MaterialApp(
        theme: buildOrvaLightTheme(),
        home: Scaffold(
          body: SingleChildScrollView(
            child: MonthGrid(
              month: day,
              selectedDay: day,
              counts: {localDateKey(day): 3},
              onSelect: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.text('10'), findsOneWidget);
  });
}
