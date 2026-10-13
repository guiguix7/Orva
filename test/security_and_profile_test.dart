import 'package:flutter_test/flutter_test.dart';
import 'package:orva/core/security/pin_security.dart';
import 'package:orva/features/quotes/quotes_data.dart';

void main() {
  group('PinSecurity', () {
    test('never stores the PIN in plain text; hash is derived with salt', () {
      final salt = PinSecurity.generateSalt();
      final hash = PinSecurity.hash('1234', salt);
      expect(hash, isNot('1234'));
      expect(hash.length, 64); // sha256 hex digest
    });

    test('verify accepts the correct PIN and rejects a wrong one', () {
      final salt = PinSecurity.generateSalt();
      final hash = PinSecurity.hash('4821', salt);
      expect(PinSecurity.verify('4821', hash, salt), true);
      expect(PinSecurity.verify('0000', hash, salt), false);
    });

    test('same PIN with different salts produces different hashes', () {
      final saltA = PinSecurity.generateSalt();
      final saltB = PinSecurity.generateSalt();
      expect(saltA, isNot(saltB));
      expect(PinSecurity.hash('1234', saltA), isNot(PinSecurity.hash('1234', saltB)));
    });

    test('format validation rejects empty, short, long and non-numeric PINs', () {
      expect(PinSecurity.validatePinFormat(''), isNotNull);
      expect(PinSecurity.validatePinFormat('123'), isNotNull);
      expect(PinSecurity.validatePinFormat('123456789'), isNotNull);
      expect(PinSecurity.validatePinFormat('12ab'), isNotNull);
      expect(PinSecurity.validatePinFormat('1234'), isNull);
      expect(PinSecurity.validatePinFormat('12345678'), isNull);
    });
  });

  group('Quote of the day', () {
    test('is stable for the same date and only uses verified quotes', () {
      final a = quoteOfTheDay(DateTime(2026, 10, 12, 8, 0));
      final b = quoteOfTheDay(DateTime(2026, 10, 12, 23, 59));
      expect(a.id, b.id);
      expect(a.verified, true);
    });

    test('differs across different dates (not guaranteed for every pair, but the pool is > 1)', () {
      final ids = {for (final d in List.generate(30, (i) => DateTime(2026, 1, i + 1))) quoteOfTheDay(d).id};
      expect(ids.length, greaterThan(1));
    });
  });
}
