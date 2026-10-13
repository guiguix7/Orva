import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';

import '../../core/database/orva_repository.dart';
import '../../core/logging/orva_diagnostics.dart';
import '../../core/security/pin_security.dart';
import '../../core/security/biometric_support.dart';
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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeTryBiometric());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _maybeTryBiometric() async {
    final repo = ref.read(repositoryProvider);
    if (!await repo.isBiometricEnabled() || !mounted) return;
    try {
      final auth = LocalAuthentication();
      if (!await OrvaBiometricSupport.canAuthenticate(auth) || !mounted) return;
      final ok = await auth.authenticate(
        localizedReason: 'Desbloqueie o Orva',
        options: const AuthenticationOptions(biometricOnly: true, stickyAuth: true),
      );
      if (ok && mounted) {
        try {
          await repo.resetPinFailures();
        } catch (_) {
          // Successful OS authentication must not be turned into a lockout if
          // the retry-counter write fails.
        }
        if (mounted) widget.onUnlocked();
      }
    } catch (error, stackTrace) {
      OrvaDiagnostics.instance.recordException(
        error,
        stackTrace,
        category: 'biometric-authentication',
        module: 'security',
        severity: DiagnosticSeverity.warning,
      );
      // In case of unsupported hardware, cancellation or plugin failure the
      // PIN remains available as a genuine fallback.
      if (mounted && _error == null) {
        setState(() => _error = 'Biometria indisponível. Você pode usar seu PIN.');
      }
    }
  }

  Future<void> _submit() async {
    if (_checking) return;
    setState(() {
      _checking = true;
      _error = null;
    });
    try {
      final repo = ref.read(repositoryProvider);
      final now = DateTime.now();
      final lockoutUntil = await repo.getPinLockoutUntil();
      if (lockoutUntil != null && lockoutUntil.isAfter(now)) {
        if (mounted) {
          setState(() => _error =
              'Muitas tentativas. Tente novamente em ${_formatWait(lockoutUntil.difference(now))}.');
        }
        return;
      }

      final stored = await repo.getPinHashAndSalt();
      if (stored == null) {
        // Recover from inconsistent legacy settings rather than locking out a
        // person whose PIN was never completely saved.
        if (mounted) widget.onUnlocked();
        return;
      }

      final pin = _controller.text;
      final formatError = PinSecurity.validatePinFormat(pin);
      if (formatError != null) {
        if (mounted) setState(() => _error = formatError);
        return;
      }

      if (PinSecurity.verify(pin, stored.hash, stored.salt)) {
        // A correct PIN must still unlock if a maintenance write fails. Retry
        // counters and legacy-hash upgrades are best-effort after verification.
        try {
          await repo.resetPinFailures();
          if (PinSecurity.needsUpgrade(stored.hash)) {
            final salt = PinSecurity.generateSalt();
            await repo.setPin(
              pinHash: PinSecurity.hash(pin, salt),
              pinSalt: salt,
            );
          }
        } catch (_) {
          // The original hash remains verifiable on the next attempt.
        }
        if (mounted) widget.onUnlocked();
      } else {
        OrvaDiagnostics.instance.record(
          severity: DiagnosticSeverity.warning,
          category: 'pin-authentication',
          module: 'security',
          message: 'PIN incorreto; valor digitado não foi registrado.',
        );
        _controller.clear();
        final newLockout = await repo.recordPinFailure();
        final attempts = await repo.getPinFailedAttempts();
        final message = newLockout == null
            ? 'PIN incorreto. $attempts de 5 tentativas antes da pausa.'
            : 'Muitas tentativas. Tente novamente em ${_formatWait(newLockout.difference(DateTime.now()))}.';
        if (mounted) setState(() => _error = message);
      }
    } catch (error, stackTrace) {
      OrvaDiagnostics.instance.recordException(
        error,
        stackTrace,
        category: 'pin-authentication',
        module: 'security',
      );
      if (mounted) {
        setState(() => _error = 'Não foi possível validar o PIN. Tente novamente.');
      }
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  String _formatWait(Duration duration) {
    final seconds = duration.inSeconds.clamp(1, 900).toInt();
    if (seconds >= 60) return '${(seconds + 59) ~/ 60} min';
    return '$seconds s';
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
                decoration: BoxDecoration(color: OrvaColors.primary, borderRadius: BorderRadius.circular(18)),
                child: const Icon(Icons.lock_outline_rounded, color: Colors.white, size: 26),
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
                  autofocus: false,
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
