import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orva/core/theme/orva_theme.dart';
import 'package:orva/core/widgets/orva_widgets.dart';

void main() {
  group('formatMinutes', () {
    test('formats minutes and hours without inventing a duration', () {
      expect(formatMinutes(0), '0min');
      expect(formatMinutes(45), '45min');
      expect(formatMinutes(60), '1h');
      expect(formatMinutes(95), '1h 35min');
    });
  });

  group('formatClock', () {
    test('uses a 24-hour clock with leading zeroes', () {
      expect(formatClock(0), '00:00');
      expect(formatClock(9 * 60 + 5), '09:05');
      expect(formatClock(23 * 60 + 59), '23:59');
    });
  });

  testWidgets('empty state displays guidance and invokes its action', (tester) async {
    var invoked = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildOrvaLightTheme(),
        home: Scaffold(
          body: OrvaEmptyState(
            icon: Icons.flag_outlined,
            title: 'Nenhuma meta ativa',
            message: 'Cadastre um objetivo seu.',
            actionLabel: 'Criar meta',
            onAction: () => invoked = true,
          ),
        ),
      ),
    );

    expect(find.text('Nenhuma meta ativa'), findsOneWidget);
    expect(find.text('Cadastre um objetivo seu.'), findsOneWidget);
    await tester.tap(find.text('Criar meta'));
    expect(invoked, isTrue);
  });
}
