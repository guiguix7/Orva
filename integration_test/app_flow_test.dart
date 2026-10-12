import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:orva/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('creates, reloads and removes a note through the mobile UI', (tester) async {
    await app.main();
    await tester.pumpAndSettle();

    final title = 'Nota de integração ${DateTime.now().microsecondsSinceEpoch}';
    await tester.tap(find.byIcon(Icons.grid_view_outlined));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Notas').first);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Nova nota'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(0), title);
    await tester.enterText(find.byType(TextFormField).at(1), 'Conteúdo salvo no banco local do Orva.');
    await tester.tap(find.text('Salvar nota'));
    await tester.pumpAndSettle();
    expect(find.text(title), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Notas').first);
    await tester.pumpAndSettle();
    expect(find.text(title), findsOneWidget);

    await tester.tap(find.byType(PopupMenuButton<String>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Excluir').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Excluir').last);
    await tester.pumpAndSettle();
    expect(find.text(title), findsNothing);
  });
}
