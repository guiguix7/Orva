/// Hashing local do PIN de bloqueio do aplicativo.
///
/// O PIN nunca é armazenado em texto puro (ver requisito 7 do prompt
/// mestre). Aqui usamos SHA-256 com um salt aleatório de 16 bytes por
/// dispositivo/configuração, seguindo o padrão comum de "salted hash" —
/// isso impede que o valor salvo em `settings` seja revertido para o PIN
/// original apenas lendo o banco local.
///
/// Limitação documentada: isto protege o PIN armazenado, mas não é
/// criptografia do banco de dados como um todo. O conteúdo das demais
/// tabelas (diário, notas, saúde) continua em texto plano no SQLite local,
/// como já indicado na tela de Configurações. Não prometa mais do que isso.
library;

import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';

class PinSecurity {
  const PinSecurity._();

  static final Random _random = Random.secure();

  /// Gera um salt aleatório (32 caracteres hex = 16 bytes).
  static String generateSalt() {
    final bytes = List<int>.generate(16, (_) => _random.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  /// Calcula o hash SHA-256 de `salt + pin`.
  static String hash(String pin, String salt) {
    final digest = sha256.convert(utf8.encode('$salt:$pin'));
    return digest.toString();
  }

  /// Confere se o PIN informado corresponde ao hash armazenado.
  static bool verify(String pin, String storedHash, String storedSalt) {
    return hash(pin, storedSalt) == storedHash;
  }

  /// Validação mínima de formato: 4 a 8 dígitos numéricos.
  static String? validatePinFormat(String pin) {
    if (pin.isEmpty) return 'Informe um PIN.';
    if (!RegExp(r'^\d{4,8}$').hasMatch(pin)) return 'O PIN deve ter de 4 a 8 dígitos numéricos.';
    return null;
  }
}
