import 'package:flutter_test/flutter_test.dart';
import 'package:orva/core/logging/orva_diagnostics.dart';

void main() {
  group('OrvaDiagnostics', () {
    final diagnostics = OrvaDiagnostics.instance;

    tearDown(() => diagnostics.clear());

    test('sanitizes credential values and email addresses', () {
      final result = OrvaDiagnostics.sanitize(
        'access_token=abc123 Bearer eyJhbGci.user.signature user@example.com PIN: 1234',
      );

      expect(result, contains('access_token=[redigido]'));
      expect(result, contains('Bearer [redigido]'));
      expect(result, contains('[e-mail]'));
      expect(result, contains('PIN: [redigido]'));
      expect(result, isNot(contains('abc123')));
      expect(result, isNot(contains('user@example.com')));
    });

    test('keeps only the latest bounded number of events', () {
      diagnostics.clear();
      for (var index = 0; index <= OrvaDiagnostics.maxEvents; index++) {
        diagnostics.record(
          severity: DiagnosticSeverity.info,
          category: 'test',
          module: 'unit',
          message: 'message ' + index.toString(),
        );
      }

      expect(diagnostics.events, hasLength(OrvaDiagnostics.maxEvents));
      expect(diagnostics.events.first.message, 'message 500');
      expect(diagnostics.events.last.message, 'message 1');
    });

    test('exports only sanitized event fields', () {
      diagnostics.clear();
      diagnostics.record(
        severity: DiagnosticSeverity.error,
        category: 'auth',
        module: 'login',
        message: 'refresh_token=private-value failed',
      );

      final exported = diagnostics.exportText();
      expect(exported, contains('ERROR'));
      expect(exported, isNot(contains('Bearer')));
      expect(exported, contains('refresh_token=[redigido]'));
      expect(exported, isNot(contains('private-value')));
    });
  });
}
