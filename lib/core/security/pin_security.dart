/// Secure local PIN hashing for the Orva app.
///
/// New PINs use PBKDF2-HMAC-SHA256 with a per-PIN random salt. The legacy
/// salted SHA-256 format remains verifiable so an existing user's PIN keeps
/// working; callers can transparently upgrade the hash after a successful
/// verification. This does not encrypt the SQLite database itself.
library;

import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';

class PinSecurity {
  const PinSecurity._();

  static final Random _random = Random.secure();

  static const String _format = 'pbkdf2-sha256';
  static const int iterations = 120000;
  static const int _maxAcceptedIterations = 500000;

  /// Generates a salt from 16 cryptographically secure random bytes.
  static String generateSalt() {
    final bytes = List<int>.generate(16, (_) => _random.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  /// Returns a versioned PBKDF2-HMAC-SHA256 representation.
  static String hash(String pin, String salt) {
    final derived = _pbkdf2(
      password: utf8.encode(pin),
      salt: utf8.encode(salt),
      rounds: iterations,
    );
    return '$_format\u0024$iterations\u0024${_toHex(derived)}';
  }

  /// Verifies both the current PBKDF2 format and the legacy salted SHA-256
  /// format. The legacy format is accepted only for migration after login.
  static bool verify(String pin, String storedHash, String storedSalt) {
    final parts = storedHash.split(r'$');
    if (parts.length == 3 && parts[0] == _format) {
      final rounds = int.tryParse(parts[1]);
      // Bound work when reading a hash from local storage. Refuse suspicious
      // values rather than allowing a corrupted file to freeze the UI.
      if (rounds == null || rounds < iterations || rounds > _maxAcceptedIterations) {
        return false;
      }
      final actual = _toHex(_pbkdf2(
        password: utf8.encode(pin),
        salt: utf8.encode(storedSalt),
        rounds: rounds,
      ));
      return _constantTimeEquals(actual, parts[2]);
    }

    // Backward compatibility with Orva builds that stored sha256("$salt:$pin").
    final legacy = sha256.convert(utf8.encode('$storedSalt:$pin')).toString();
    return _constantTimeEquals(legacy, storedHash);
  }

  static bool needsUpgrade(String storedHash) =>
      !storedHash.startsWith('$_format\u0024');

  /// Validates a PIN with 4 to 8 numeric digits.
  static String? validatePinFormat(String pin) {
    if (pin.isEmpty) return 'Informe um PIN.';
    if (!RegExp(r'^\d{4,8}$').hasMatch(pin)) {
      return 'O PIN deve ter de 4 a 8 dígitos numéricos.';
    }
    return null;
  }

  static List<int> _pbkdf2({
    required List<int> password,
    required List<int> salt,
    required int rounds,
  }) {
    final hmac = Hmac(sha256, password);
    final firstBlock = <int>[...salt, 0, 0, 0, 1];
    var u = hmac.convert(firstBlock).bytes;
    final output = List<int>.from(u);
    for (var round = 1; round < rounds; round++) {
      u = hmac.convert(u).bytes;
      for (var i = 0; i < output.length; i++) {
        output[i] ^= u[i];
      }
    }
    return output;
  }

  static String _toHex(List<int> bytes) =>
      bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

  static bool _constantTimeEquals(String left, String right) {
    var difference = left.length ^ right.length;
    final length = max(left.length, right.length);
    for (var i = 0; i < length; i++) {
      final a = i < left.length ? left.codeUnitAt(i) : 0;
      final b = i < right.length ? right.codeUnitAt(i) : 0;
      difference |= a ^ b;
    }
    return difference == 0;
  }
}
