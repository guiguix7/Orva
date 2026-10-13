import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orva/core/security/pin_security.dart';
import 'package:orva/features/quotes/quotes_data.dart';

void main() {
  group('PinSecurity', () {
    test('new PINs use a versioned slow hash, not plain text', () {
      final salt = PinSecurity.generateSalt();
      final hash = PinSecurity.hash('1234', salt);
      final separator = String.fromCharCode(36);
      expect(hash, isNot('1234'));
      expect(
        hash.startsWith(
          'pbkdf2-sha256' + separator + PinSecurity.iterations.toString() + separator,
        ),
        isTrue,
      );
      expect(hash.substring(hash.lastIndexOf(separator) + 1).length, 64);
      expect(PinSecurity.needsUpgrade(hash), isFalse);
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

    test('legacy salted SHA-256 PINs remain verifiable for safe migration', () {
      const salt = '00112233445566778899aabbccddeeff';
      final legacy = sha256.convert(utf8.encode(salt + ':1234')).toString();
      expect(PinSecurity.verify('1234', legacy, salt), isTrue);
      expect(PinSecurity.verify('4321', legacy, salt), isFalse);
      expect(PinSecurity.needsUpgrade(legacy), isTrue);
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
