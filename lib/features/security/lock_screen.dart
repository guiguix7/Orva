import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';

import '../../core/database/orva_repository.dart';
import '../../core/security/pin_security.dart';
import '../../core/theme/orva_theme.dart';

/// Tela de desbloqueio por PIN (e biometria opcional). Não é apenas uma
/// camada visual: `onUnlocked` só é chamado depois de validar o hash salvo.
class LockScreen extends ConsumerStatefulWidget {
  const LockScreen({super.key, required this.onUnlocked});
  final VoidCallback onUnlocked;

  @override
  ConsumerState<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends ConsumerState<LockScreen> {
  final _controller = TextEditingController();
  String? _error;
  bool _checking = false;
  int _remainingSeconds = 0;
  DateTime? _lockoutUntil;
  Timer? _cooldownTimer;

  static const _failedAttemptsKey = 'security_failed_pin_attempts';
  static const _lockUntilKey = 'security_pin_lock_until';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _maybeTryBiometric();
      _loadLockout();
    });
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _maybeTryBiometric() async {
    try {
      final repo = ref.read(repositoryProvider);
      if (!await repo.isBiometricEnabled()) return;
      final auth = LocalAuthentication();
      final ok = await auth.authenticate(
        localizedReason: 'Desbloqueie o Orva',
        options: const AuthenticationOptions(biometricOnly: true, stickyAuth: true),
      );
      if (ok && mounted) {
        try {
          await repo.execute(
            'DELETE FROM settings WHERE setting_key IN (?, ?)',
            [_failedAttemptsKey, _lockUntilKey],
          );
        } catch (_) {
          // A biometria validada continua permitindo acesso mesmo se a
          // limpeza administrativa do contador falhar.
        }
        widget.onUnlocked();
      }
    } catch (_) {
      // Falha ao ler a preferência, ausência de hardware ou cancelamento
      // nunca deve impedir o uso do PIN abaixo.
    }
  }

  Future<void> _loadLockout() async {
    try {
      final repo = ref.read(repositoryProvider);
      final raw = await repo.getSetting(_lockUntilKey);
      final until = DateTime.tryParse(raw ?? '');
      if (until != null && until.isAfter(DateTime.now())) {
        _startCooldown(until);
      } else if (raw != null) {
        await repo.execute('DELETE FROM settings WHERE setting_key=?', [_lockUntilKey]);
      }
    } catch (_) {
      // Se as preferências de bloqueio não puderem ser lidas, a tela não deve
      // ficar presa em um estado de carregamento permanente.
    }
  }

  void _startCooldown(DateTime until) {
    _cooldownTimer?.cancel();
    _lockoutUntil = until;
    _updateCooldown();
    _cooldownTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _updateCooldown(),
    );
  }

  void _updateCooldown() {
    if (!mounted) return;
    final remaining = _lockoutUntil?.difference(DateTime.now()).inSeconds.ceil() ?? 0;
    final clamped = remaining > 0 ? remaining : 0;
    setState(() {
      _remainingSeconds = clamped;
      if (clamped == 0 && _error?.startsWith('Muitas tentativas') == true) {
        _error = null;
      }
    });
    if (clamped == 0) {
      _cooldownTimer?.cancel();
      _cooldownTimer = null;
      _lockoutUntil = null;
    }
  }

  Future<void> _submit() async {
    if (_checking) return;
    setState(() { _checking = true; _error = null; });
    try {
      final repo = ref.read(repositoryProvider);
      // Re-read the timestamp before every attempt, so a quick tap or cold
      // restart cannot bypass a persisted lockout.
      final rawLockUntil = await repo.getSetting(_lockUntilKey);
      final persistedLockUntil = DateTime.tryParse(rawLockUntil ?? '');
      if (persistedLockUntil != null && persistedLockUntil.isAfter(DateTime.now())) {
        _startCooldown(persistedLockUntil);
        if (mounted) {
          setState(() => _error =
              'Muitas tentativas. Tente novamente em $_remainingSeconds s.');
        }
        return;
      }

      final stored = await repo.getPinHashAndSalt();
      if (stored == null) {
        // Nenhum PIN configurado (estado inconsistente) — não bloqueia o usuário.
        widget.onUnlocked();
        return;
      }
      if (PinSecurity.verify(_controller.text, stored.hash, stored.salt)) {
        // Upgrade legacy SHA-256 PINs only after the supplied PIN was verified.
        // A failed migration must not lock a legitimate user out of local data.
        if (!stored.hash.startsWith('pbkdf2-sha256\

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(
                width: 58, height: 58,
                decoration: BoxDecoration(color: Theme.of(context).colorScheme.primary, borderRadius: BorderRadius.circular(18)),
                child: Icon(Icons.lock_outline_rounded, color: Theme.of(context).colorScheme.onPrimary, size: 26),
              ),
              const SizedBox(height: 20),
              Text('Orva está bloqueado', style: Theme.of(context).textTheme.headlineMedium, textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Text(
                _remainingSeconds > 0
                    ? 'O acesso por PIN será liberado quando o intervalo de segurança terminar.'
                    : 'Digite seu PIN para continuar.',
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 22),
              SizedBox(
                width: 220,
                child: TextField(
                  controller: _controller,
                  autofocus: _remainingSeconds == 0,
                  enabled: !_checking && _remainingSeconds == 0,
                  obscureText: true,
                  textAlign: TextAlign.center,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(8)],
                  style: orvaMonoStyle(fontSize: 22, letterSpacing: 6),
                  decoration: InputDecoration(errorText: _error, counterText: ''),
                  onSubmitted: (_) => _submit(),
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: 220,
                child: FilledButton(
                  onPressed: _checking || _remainingSeconds > 0 ? null : _submit,
                  child: _checking
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : Text(_remainingSeconds > 0 ? 'Tente em ${_remainingSeconds}s' : 'Desbloquear'),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}
)) {
          try {
            await repo.setPin(
              pinHash: PinSecurity.hash(_controller.text, stored.salt),
              pinSalt: stored.salt,
            );
          } catch (_) {}
        }
        try {
          await repo.execute(
            'DELETE FROM settings WHERE setting_key IN (?, ?)',
            [_failedAttemptsKey, _lockUntilKey],
          );
        } catch (_) {}
        widget.onUnlocked();
      } else {
        final previous = int.tryParse(
              await repo.getSetting(_failedAttemptsKey) ?? '0',
            ) ??
            0;
        final failedAttempts = previous + 1;
        await repo.setSetting(_failedAttemptsKey, '$failedAttempts');
        if (failedAttempts >= 5) {
          final seconds = switch (failedAttempts - 5) {
            0 => 30,
            1 => 60,
            2 => 120,
            3 => 240,
            _ => 300,
          };
          final until = DateTime.now().add(Duration(seconds: seconds));
          await repo.setSetting(_lockUntilKey, until.toIso8601String());
          _startCooldown(until);
          if (mounted) {
            setState(() => _error =
                'Muitas tentativas. Tente novamente em $_remainingSeconds s.');
          }
        } else {
          if (mounted) {
            setState(() => _error =
                'PIN incorreto. Tentativa $failedAttempts de 5.');
          }
        }
        _controller.clear();
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Não foi possível verificar o PIN agora. Tente novamente.');
        _controller.clear();
      }
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(
                width: 58, height: 58,
                decoration: BoxDecoration(color: Theme.of(context).colorScheme.primary, borderRadius: BorderRadius.circular(18)),
                child: Icon(Icons.lock_outline_rounded, color: Theme.of(context).colorScheme.onPrimary, size: 26),
              ),
              const SizedBox(height: 20),
              Text('Orva está bloqueado', style: Theme.of(context).textTheme.headlineMedium, textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Text('Digite seu PIN para continuar.', style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 22),
              SizedBox(
                width: 220,
                child: TextField(
                  controller: _controller,
                  autofocus: true,
                  obscureText: true,
                  textAlign: TextAlign.center,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(8)],
                  style: orvaMonoStyle(fontSize: 22, letterSpacing: 6),
                  decoration: InputDecoration(errorText: _error, counterText: ''),
                  onSubmitted: (_) => _submit(),
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: 220,
                child: FilledButton(
                  onPressed: _checking ? null : _submit,
                  child: _checking ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Desbloquear'),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}
