import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';

import '../../core/database/orva_repository.dart';
import '../../core/security/pin_security.dart';
import '../../core/theme/orva_theme.dart';
import '../../core/widgets/orva_widgets.dart';

/// Configurações de bloqueio local (PIN + biometria opcional).
///
/// Limitação conhecida: a integração com `local_auth` não pôde ser testada
/// em um dispositivo/emulador real neste ambiente de desenvolvimento (sem
/// Flutter SDK disponível). O código trata a ausência/erro do plugin com
/// try/catch e informa o usuário quando a biometria não está disponível,
/// mas a configuração nativa (Info.plist/AndroidManifest) deve ser conferida
/// antes de distribuir o aplicativo — ver README.
class SecuritySettingsPage extends ConsumerStatefulWidget {
  const SecuritySettingsPage({super.key});
  @override
  ConsumerState<SecuritySettingsPage> createState() => _SecuritySettingsPageState();
}

class _SecuritySettingsPageState extends ConsumerState<SecuritySettingsPage> {
  bool _loading = true;
  bool _lockEnabled = false;
  bool _biometricEnabled = false;
  bool _biometricAvailable = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final repo = ref.read(repositoryProvider);
    final lockEnabled = await repo.isLockEnabled();
    final biometricEnabled = await repo.isBiometricEnabled();
    bool biometricAvailable = false;
    try {
      final auth = LocalAuthentication();
      final canCheck = await auth.canCheckBiometrics;
      final supported = await auth.isDeviceSupported();
      final enrolled = canCheck && (await auth.getAvailableBiometrics()).isNotEmpty;
      biometricAvailable = canCheck && supported && enrolled;
    } catch (_) {
      biometricAvailable = false;
    }
    if (!mounted) return;
    setState(() {
      _lockEnabled = lockEnabled;
      _biometricEnabled = biometricEnabled;
      _biometricAvailable = biometricAvailable;
      _loading = false;
    });
  }

  Future<void> _setupPin() async {
    final pin = await _askPin(title: 'Criar PIN', confirm: true);
    if (pin == null || !mounted) return;
    setState(() => _busy = true);
    try {
      final salt = PinSecurity.generateSalt();
      final hash = PinSecurity.hash(pin, salt);
      await ref.read(repositoryProvider).setPin(pinHash: hash, pinSalt: salt);
      ref.invalidate(lockEnabledProvider);
      if (mounted) {
        showOrvaMessage(context, 'Bloqueio ativado. Será solicitado ao abrir o Orva.');
        setState(() => _lockEnabled = true);
      }
    } catch (error) {
      if (mounted) showOrvaError(context, error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _changePin() async {
    final repo = ref.read(repositoryProvider);
    final stored = await repo.getPinHashAndSalt();
    if (stored == null) return;
    final current = await _askPin(title: 'Digite o PIN atual', confirm: false);
    if (current == null || !mounted) return;
    if (!PinSecurity.verify(current, stored.hash, stored.salt)) {
      if (mounted) showOrvaError(context, 'PIN atual incorreto.');
      return;
    }
    final newPin = await _askPin(title: 'Novo PIN', confirm: true);
    if (newPin == null || !mounted) return;
    setState(() => _busy = true);
    try {
      final salt = PinSecurity.generateSalt();
      final hash = PinSecurity.hash(newPin, salt);
      await repo.setPin(pinHash: hash, pinSalt: salt);
      if (mounted) showOrvaMessage(context, 'PIN alterado.');
    } catch (error) {
      if (mounted) showOrvaError(context, error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _disableLock() async {
    final confirmed = await confirmAction(
      context,
      title: 'Desativar bloqueio?',
      message: 'O Orva deixará de pedir PIN ou biometria ao abrir. Seus dados locais não são apagados.',
      actionLabel: 'Desativar',
      destructive: true,
    );
    if (!confirmed || !mounted) return;
    setState(() => _busy = true);
    try {
      await ref.read(repositoryProvider).disableLock();
      ref.invalidate(lockEnabledProvider);
      ref.invalidate(biometricEnabledProvider);
      if (mounted) setState(() { _lockEnabled = false; _biometricEnabled = false; });
    } catch (error) {
      if (mounted) showOrvaError(context, error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _toggleBiometric(bool value) async {
    if (value && !_biometricAvailable) {
      showOrvaMessage(context, 'Biometria indisponível neste dispositivo. Verifique se há digital/rosto cadastrados no sistema.');
      return;
    }
    setState(() => _busy = true);
    try {
      await ref.read(repositoryProvider).setBiometricEnabled(value);
      ref.invalidate(biometricEnabledProvider);
      if (mounted) setState(() => _biometricEnabled = value);
    } catch (error) {
      if (mounted) showOrvaError(context, error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<String?> _askPin({required String title, required bool confirm}) async {
    final controller = TextEditingController();
    final confirmController = TextEditingController();
    String? error;
    final result = await showDialog<String>(
      context: context,
      builder: (context) => StatefulBuilder(builder: (context, setDialogState) {
        return AlertDialog(
          title: Text(title),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(8)],
              obscureText: true,
              decoration: InputDecoration(
                labelText: 'PIN (4 a 8 dígitos)',
                errorText: error,
              ),
              autofocus: true,
            ),
            if (confirm) ...[
              const SizedBox(height: 10),
              TextField(
                controller: confirmController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(8)],
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'Confirme o PIN',
                  errorText: error,
                ),
              ),
            ],
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
            FilledButton(
              onPressed: () {
                final formatError = PinSecurity.validatePinFormat(controller.text);
                if (formatError != null) { setDialogState(() => error = formatError); return; }
                if (confirm && controller.text != confirmController.text) {
                  setDialogState(() => error = 'Os PINs não coincidem.');
                  return;
                }
                Navigator.pop(context, controller.text);
              },
              child: const Text('Confirmar'),
            ),
          ],
        );
      }),
    );
    controller.dispose();
    confirmController.dispose();
    return result;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Bloqueio do app')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(padding: const EdgeInsets.fromLTRB(20, 10, 20, 28), children: [
              Text('Proteja o Orva com um PIN local ou biometria do aparelho. Nada disso envolve conta ou nuvem.', style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 18),
              OrvaSurface(child: Column(children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Bloqueio com PIN'),
                  subtitle: Text(_lockEnabled ? 'Ativado' : 'Desativado'),
                  value: _lockEnabled,
                  onChanged: _busy ? null : (value) => value ? _setupPin() : _disableLock(),
                ),
                if (_lockEnabled) ...[
                  const Divider(height: 1),
                  ListTile(contentPadding: EdgeInsets.zero, title: const Text('Alterar PIN'), trailing: const Icon(Icons.chevron_right_rounded), onTap: _busy ? null : _changePin),
                  const Divider(height: 1),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Também permitir biometria'),
                    subtitle: Text(_biometricAvailable ? 'Digital ou reconhecimento facial do aparelho' : 'Indisponível neste dispositivo'),
                    value: _biometricEnabled,
                    onChanged: _busy ? null : _toggleBiometric,
                  ),
                ],
              ])),
              const SizedBox(height: 18),
              const OrvaSurface(child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Icon(Icons.info_outline_rounded, color: OrvaColors.information),
                SizedBox(width: 10),
                Expanded(child: Text('O PIN é guardado apenas como um hash (não é possível recuperá-lo). Se esquecer o PIN, a única forma de recuperação neste MVP é desativar o bloqueio reinstalando o aplicativo, o que apaga os dados locais — por isso prefira algo memorável.')),
              ])),
            ]),
    );
  }
}
