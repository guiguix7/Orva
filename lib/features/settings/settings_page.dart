import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/database/orva_repository.dart';
import '../../core/theme/orva_theme.dart';
import '../../core/widgets/orva_widgets.dart';
import '../security/security_settings_page.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});
  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  final _name = TextEditingController();
  bool _loading = true;
  String _theme = 'light';
  bool _busy = false;
  bool _quotesEnabled = true;

  @override
  void initState() { super.initState(); _load(); }
  @override
  void dispose() { _name.dispose(); super.dispose(); }

  Future<void> _load() async {
    try {
      final repo = ref.read(repositoryProvider);
      final values = await Future.wait<String?>([repo.getSetting('user_name'), repo.getSetting('theme'), repo.getSetting('quotes_enabled')]);
      if (!mounted) return;
      setState(() { _name.text = values[0] ?? ''; _theme = values[1] ?? 'light'; _quotesEnabled = values[2] != '0'; _loading = false; });
    } catch (error) { if (mounted) { setState(() => _loading = false); showOrvaError(context, error); } }
  }

  Future<void> _saveProfile() async {
    setState(() => _busy = true);
    try {
      final repo = ref.read(repositoryProvider);
      await repo.setSetting('user_name', _name.text.trim());
      await repo.setSetting('theme', _theme);
      await repo.setSetting('quotes_enabled', _quotesEnabled ? '1' : '0');
      ref.invalidate(themeNameProvider);
      ref.invalidate(userNameProvider);
      ref.invalidate(quotesEnabledProvider);
      if (mounted) showOrvaMessage(context, 'Preferências salvas neste dispositivo.');
    } catch (error) { if (mounted) showOrvaError(context, error); }
    finally { if (mounted) setState(() => _busy = false); }
  }

  Future<void> _exportBackup() async {
    setState(() => _busy = true);
    try {
      final repo = ref.read(repositoryProvider);
      final backup = await repo.exportBackup();
      final json = const JsonEncoder.withIndent('  ').convert(backup);
      final bytes = Uint8List.fromList(utf8.encode(json));
      final result = await SharePlus.instance.share(ShareParams(
        title: 'Backup do Orva',
        text: 'Backup local do Orva. Guarde este arquivo em um local seguro.',
        files: [XFile.fromData(bytes, mimeType: 'application/json', name: 'orva-backup.json')],
        fileNameOverrides: const ['orva-backup.json'],
      ));
      if (mounted && result.status == ShareResultStatus.success) {
        showOrvaMessage(context, 'O backup foi enviado ao destino escolhido.');
      } else if (mounted && result.status == ShareResultStatus.dismissed) showOrvaMessage(context, 'Compartilhamento cancelado. O banco local não foi alterado.');
    } catch (error) { if (mounted) showOrvaError(context, error); }
    finally { if (mounted) setState(() => _busy = false); }
  }

  Future<void> _importBackup() async {
    try {
      final result = await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: ['json']);
      if (result.isEmpty) return;
      final bytes = await result.first.readAsBytes();
      final decoded = jsonDecode(utf8.decode(bytes));
      if (!mounted) return;
      final accepted = await confirmAction(
        context,
        title: 'Substituir dados atuais?',
        message: 'A importação substituirá os dados locais atuais pelos dados do backup selecionado. Faça um backup do estado atual antes de continuar, se quiser preservá-lo.',
        actionLabel: 'Validar e importar',
        destructive: true,
      );
      if (!accepted || !mounted) return;
      setState(() => _busy = true);
      await ref.read(repositoryProvider).importBackup(decoded);
      ref.invalidate(themeNameProvider);
      ref.invalidate(userNameProvider);
      ref.invalidate(databaseReadyProvider);
      if (mounted) {
        showOrvaMessage(context, 'Backup importado. As telas serão atualizadas ao reabrir cada seção.');
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } catch (error) {
      if (mounted) showOrvaError(context, error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Configurações')),
      body: _loading ? const Center(child: CircularProgressIndicator()) : ListView(padding: const EdgeInsets.fromLTRB(20, 10, 20, 28), children: [
        Text('Perfil local', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 6),
        Text('Sem conta e sem sincronização. O nome é opcional.', style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: 14),
        TextField(controller: _name, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'Como gostaria de ser chamado?', hintText: 'Nome opcional')),
        const SizedBox(height: 24),
        Text('Aparência', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 10),
        OrvaSurface(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4), child: Column(children: [
          RadioListTile<String>(value: 'light', groupValue: _theme, title: const Text('Claro'), secondary: const Icon(Icons.light_mode_outlined), onChanged: (value) => setState(() => _theme = value ?? 'light'), contentPadding: EdgeInsets.zero),
          const Divider(height: 1),
          RadioListTile<String>(value: 'dark', groupValue: _theme, title: const Text('Escuro'), secondary: const Icon(Icons.dark_mode_outlined), onChanged: (value) => setState(() => _theme = value ?? 'dark'), contentPadding: EdgeInsets.zero),
          const Divider(height: 1),
          RadioListTile<String>(value: 'system', groupValue: _theme, title: const Text('Seguir sistema'), secondary: const Icon(Icons.brightness_6_outlined), onChanged: (value) => setState(() => _theme = value ?? 'system'), contentPadding: EdgeInsets.zero),
          const Divider(height: 1),
          RadioListTile<String>(value: 'dayNight', groupValue: _theme, title: const Text('Automático por horário'), subtitle: const Text('Claro das 07h às 19h e escuro à noite'), secondary: const Icon(Icons.nights_stay_outlined), onChanged: (value) => setState(() => _theme = value ?? 'dayNight'), contentPadding: EdgeInsets.zero),
        ])),
        const SizedBox(height: 14),
        OrvaSurface(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2), child: SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Frases filosóficas'),
          subtitle: const Text('Mostra uma reflexão diferente por dia na Home'),
          value: _quotesEnabled,
          onChanged: (value) => setState(() => _quotesEnabled = value),
        )),
        const SizedBox(height: 14),
        SizedBox(width: double.infinity, child: FilledButton(onPressed: _busy ? null : _saveProfile, child: _busy ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Salvar preferências'))),
        const SizedBox(height: 30),
        Text('Segurança', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 6),
        Text('Bloqueio local com PIN ou biometria. Nenhum dado sai do dispositivo.', style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: 14),
        OrvaSurface(onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const SecuritySettingsPage())), child: const Row(children: [
          Icon(Icons.lock_outline_rounded, color: OrvaColors.primary),
          SizedBox(width: 12),
          Expanded(child: Text('Bloqueio do app')),
          Icon(Icons.chevron_right_rounded, color: OrvaColors.tertiaryText),
        ])),
        const SizedBox(height: 30),
        Text('Backup local', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 6),
        Text('Exporte seus registros para um JSON versionado e restaure-os depois, sem conta ou nuvem.', style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: 14),
        OrvaSurface(child: Column(children: [
          Row(children: [Container(width: 42, height: 42, decoration: BoxDecoration(color: OrvaColors.primary.withValues(alpha: 0.09), borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.file_upload_outlined, color: OrvaColors.primary)), const SizedBox(width: 12), const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Exportar backup', style: TextStyle(fontWeight: FontWeight.w600)), SizedBox(height: 3), Text('Compartilhe ou salve uma cópia de todos os dados.', style: TextStyle(fontSize: 13, color: OrvaColors.secondaryText))])), IconButton(tooltip: 'Exportar', onPressed: _busy ? null : _exportBackup, icon: const Icon(Icons.arrow_forward_rounded))]),
          const Divider(height: 24),
          Row(children: [Container(width: 42, height: 42, decoration: BoxDecoration(color: OrvaColors.terracotta.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.file_download_outlined, color: OrvaColors.terracotta)), const SizedBox(width: 12), const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Importar backup', style: TextStyle(fontWeight: FontWeight.w600)), SizedBox(height: 3), Text('Valida o arquivo antes de substituir os dados atuais.', style: TextStyle(fontSize: 13, color: OrvaColors.secondaryText))])), IconButton(tooltip: 'Importar', onPressed: _busy ? null : _importBackup, icon: const Icon(Icons.arrow_forward_rounded))]),
        ])),
        const SizedBox(height: 18),
        const OrvaSurface(child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(Icons.privacy_tip_outlined, color: OrvaColors.information), SizedBox(width: 10), Expanded(child: Text('Os dados do Orva ficam no armazenamento local do aplicativo. Isso não equivale a criptografia de ponta a ponta nem a um cofre criptografado. Guarde seus backups com cuidado.'))])),
        const SizedBox(height: 26),
        Text('Orva · versão 1.0.0', style: Theme.of(context).textTheme.bodySmall, textAlign: TextAlign.center),
      ]),
    );
  }
}
