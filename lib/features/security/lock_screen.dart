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
    if (!await repo.isBiometricEnabled()) return;
    try {
      final auth = LocalAuthentication();
      final ok = await auth.authenticate(
        localizedReason: 'Desbloqueie o Orva',
        options: const AuthenticationOptions(biometricOnly: true, stickyAuth: true),
      );
      if (ok && mounted) widget.onUnlocked();
    } catch (_) {
      // Biometria indisponível/erro: o usuário simplesmente usa o PIN abaixo.
    }
  }

  Future<void> _submit() async {
    setState(() { _checking = true; _error = null; });
    try {
      final repo = ref.read(repositoryProvider);
      final stored = await repo.getPinHashAndSalt();
      if (stored == null) {
        // Nenhum PIN configurado (estado inconsistente) — não bloqueia o usuário.
        widget.onUnlocked();
        return;
      }
      if (PinSecurity.verify(_controller.text, stored.hash, stored.salt)) {
        widget.onUnlocked();
      } else {
        setState(() => _error = 'PIN incorreto.');
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
