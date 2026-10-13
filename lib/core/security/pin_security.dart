/// Local PIN verification. New PINs use PBKDF2-HMAC-SHA256 with a random
/// salt. Legacy SHA-256 salted hashes remain verifiable and are upgraded when
/// the user successfully unlocks, avoiding a forced reset of existing PINs.
library;

import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

class PinSecurity {
  const PinSecurity._();

  static const int _iterations = 100000;
  static const String _algorithm = 'pbkdf2-sha256';
  static final Random _random = Random.secure();

  /// Salt encoded as 32 hexadecimal characters (16 random bytes).
  static String generateSalt() {
    final bytes = List<int>.generate(16, (_) => _random.nextInt(256));
    return _hex(bytes);
  }

  /// Encodes the algorithm and iteration count with the derived key so this
  /// can be evolved safely in a future migration.
  static String hash(String pin, String salt) {
    final key = _pbkdf2(
      password: utf8.encode(pin),
      salt: utf8.encode(salt),
      iterations: _iterations,
    );
    return '$_algorithm\$_iterations\${_hex(key)}';
  }

  static bool verify(String pin, String storedHash, String storedSalt) {
    if (storedHash.startsWith('$_algorithm\$')) {
      final parts = storedHash.split('\$');
      if (parts.length != 3) return false;
      final iterations = int.tryParse(parts[1]);
      // Treat local storage as untrusted input and cap the work factor to
      // avoid malformed settings causing a denial of service on unlock.
      if (iterations == null || iterations < 10000 || iterations > 500000) {
        return false;
      }
      final actual = _hex(_pbkdf2(
        password: utf8.encode(pin),
        salt: utf8.encode(storedSalt),
        iterations: iterations,
      ));
      return _constantTimeEquals(actual, parts[2]);
    }

    // Backward compatibility for existing Orva installations; LockScreen
    // upgrades this hash after a successful verification.
    final legacy = sha256.convert(utf8.encode('$storedSalt:$pin')).toString();
    return _constantTimeEquals(legacy, storedHash);
  }

  static List<int> _pbkdf2({
    required List<int> password,
    required List<int> salt,
    required int iterations,
  }) {
    final hmac = Hmac(sha256, password);
    final firstBlock = hmac.convert([...salt, 0, 0, 0, 1]).bytes;
    var u = firstBlock;
    final output = List<int>.from(firstBlock);
    for (var round = 1; round < iterations; round++) {
      u = hmac.convert(u).bytes;
      for (var i = 0; i < output.length; i++) {
        output[i] ^= u[i];
      }
    }
    return output;
  }

  static String _hex(List<int> bytes) =>
      bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();

  static bool _constantTimeEquals(String a, String b) {
    if (a.length != b.length) return false;
    var difference = 0;
    for (var i = 0; i < a.length; i++) {
      difference |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return difference == 0;
  }

  /// PIN must contain 4 to 8 numeric digits.
  static String? validatePinFormat(String pin) {
    if (pin.isEmpty) return 'Informe um PIN.';
    if (!RegExp(r'^\d{4,8}$').hasMatch(pin)) {
      return 'O PIN deve ter de 4 a 8 dígitos numéricos.';
    }
    return null;
  }
}
