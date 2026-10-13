import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/database/orva_repository.dart';
import '../../core/theme/orva_theme.dart';
import '../../core/widgets/orva_widgets.dart';

class JournalPage extends ConsumerStatefulWidget {
  const JournalPage({super.key});
  @override
  ConsumerState<JournalPage> createState() => _JournalPageState();
}

class _JournalPageState extends ConsumerState<JournalPage> {
  final _search = TextEditingController();
  bool _loading = true;
  List<Map<String, Object?>> _entries = [];
  @override
  void initState() { super.initState(); _load(); }
  @override
  void dispose() { _search.dispose(); super.dispose(); }
  Future<void> _load() async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      final entries = await ref.read(repositoryProvider).getJournalEntries(search: _search.text);
      if (!mounted) return;
      setState(() { _entries = entries; _loading = false; });
    } catch (error) { if (mounted) { setState(() => _loading = false); showOrvaError(context, error); } }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    floatingActionButton: FloatingActionButton.extended(onPressed: () async { await showJournalEditor(context, ref, DateTime.now()); await _load(); }, icon: const Icon(Icons.add), label: const Text('Escrever hoje')),
    body: SafeArea(child: Column(children: [
      const OrvaPageHeader(title: 'Diário', subtitle: 'Um registro privado dos seus dias, ideias e reflexões.'),
      Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: TextField(controller: _search, onChanged: (_) => _load(), decoration: InputDecoration(prefixIcon: const Icon(Icons.search), hintText: 'Pesquisar registros', suffixIcon: _search.text.isEmpty ? null : IconButton(onPressed: () { _search.clear(); _load(); }, icon: const Icon(Icons.close))))),
      const SizedBox(height: 14),
      Expanded(child: _loading ? const Center(child: CircularProgressIndicator()) : _entries.isEmpty
        ? ListView(children: [OrvaEmptyState(icon: Icons.menu_book_outlined, title: _search.text.isEmpty ? 'Uma página em branco' : 'Nenhuma entrada encontrada', message: _search.text.isEmpty ? 'Escreva o que fizer sentido para você. O humor é opcional e nunca é deduzido automaticamente.' : 'Experimente outro termo de busca.', actionLabel: _search.text.isEmpty ? 'Escrever primeira entrada' : null, onAction: _search.text.isEmpty ? () async { await showJournalEditor(context, ref, DateTime.now()); await _load(); } : null)])
        : RefreshIndicator(onRefresh: _load, child: ListView.separated(padding: const EdgeInsets.fromLTRB(20, 4, 20, 100), itemCount: _entries.length, separatorBuilder: (_, _) => const SizedBox(height: 10), itemBuilder: (context, index) {
          final entry = _entries[index];
          final tags = _decodeTags(entry['tags_json']);
          return OrvaSurface(onTap: () async { await showJournalEditor(context, ref, DateTime.parse(entry['entry_date'] as String), entry: entry); await _load(); }, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [Expanded(child: Text(_dateLabel(entry['entry_date'] as String), style: Theme.of(context).textTheme.titleMedium)), if ((entry['mood'] as String?)?.isNotEmpty == true) _MoodChip(mood: entry['mood'] as String), PopupMenuButton<String>(onSelected: (choice) async {
              if (choice == 'edit') {
                await showJournalEditor(context, ref, DateTime.parse(entry['entry_date'] as String), entry: entry);
                if (!mounted) return;
                await _load();
              } else if (choice == 'delete') {
                final ok = await confirmAction(
                  context,
                  title: 'Excluir entrada?',
                  message: 'Esta entrada do diário será removida permanentemente deste dispositivo.',
                  actionLabel: 'Excluir',
                  destructive: true,
                );
                if (!mounted || !ok) return;
                await ref.read(repositoryProvider).deleteJournalEntry(entry['id'] as String);
                if (!mounted) return;
                await _load();
              }
            }, itemBuilder: (_) => const [PopupMenuItem(value: 'edit', child: Text('Editar')), PopupMenuItem(value: 'delete', child: Text('Excluir'))])]),
            const SizedBox(height: 8), Text('${entry['content']}', maxLines: 5, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodyLarge),
            if (tags.isNotEmpty) ...[const SizedBox(height: 12), Wrap(spacing: 6, runSpacing: 6, children: tags.map((tag) => _JournalTag(label: tag)).toList())],
            const SizedBox(height: 10), Text('Atualizado em ${DateFormat('dd/MM/yyyy · HH:mm').format(DateTime.parse(entry['updated_at'] as String))}', style: Theme.of(context).textTheme.bodySmall),
          ]));
        }))),
    ])),
  );
}

Future<bool?> showJournalEditor(BuildContext context, WidgetRef ref, DateTime date, {Map<String, Object?>? entry}) async {
  final repo = ref.read(repositoryProvider);
  final keyDate = repo.dateKey(date);
  final existing = entry ?? await repo.getJournalEntryForDate(date);
  if (!context.mounted) return false;
  final content = TextEditingController(text: existing?['content'] as String? ?? '');
  final tags = TextEditingController(text: _decodeTags(existing?['tags_json']).join(', '));
  String? mood = existing?['mood'] as String?;
  final key = GlobalKey<FormState>();
  final result = await showDialog<bool>(context: context, builder: (dialogContext) => StatefulBuilder(builder: (context, setState) => AlertDialog(
    title: Text(existing == null ? 'Diário · ${DateFormat('dd/MM/yyyy').format(date)}' : 'Editar entrada · ${DateFormat('dd/MM/yyyy').format(date)}'),
    content: SizedBox(width: 500, child: Form(key: key, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
      TextFormField(controller: content, autofocus: true, minLines: 7, maxLines: 14, textCapitalization: TextCapitalization.sentences, decoration: const InputDecoration(labelText: 'Como foi seu dia?', hintText: 'Escreva sem se preocupar com a forma…', alignLabelWithHint: true), validator: (value) => value == null || value.trim().isEmpty ? 'Escreva algo antes de salvar.' : null),
      const SizedBox(height: 12),
      DropdownButtonFormField<String?>(initialValue: mood, decoration: const InputDecoration(labelText: 'Humor (opcional)'), items: const [DropdownMenuItem<String?>(value: null, child: Text('Não informar')), DropdownMenuItem<String?>(value: 'Ótimo', child: Text('Ótimo')), DropdownMenuItem<String?>(value: 'Bem', child: Text('Bem')), DropdownMenuItem<String?>(value: 'Neutro', child: Text('Neutro')), DropdownMenuItem<String?>(value: 'Difícil', child: Text('Difícil')), DropdownMenuItem<String?>(value: 'Muito difícil', child: Text('Muito difícil'))], onChanged: (value) => setState(() => mood = value)),
      const SizedBox(height: 12), TextFormField(controller: tags, decoration: const InputDecoration(labelText: 'Palavras-chave (opcional)', hintText: 'Separadas por vírgula')),
      const SizedBox(height: 6), Align(alignment: Alignment.centerLeft, child: Text('Este diário é local. O conteúdo não é enviado para serviços externos e o armazenamento local não equivale a um cofre criptografado.', style: Theme.of(context).textTheme.bodySmall)),
    ])))),
    actions: [TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancelar')), FilledButton(onPressed: () async { if (!key.currentState!.validate()) return; try { await repo.saveJournalEntry(id: existing?['id'] as String?, entryDate: keyDate, content: content.text, mood: mood, tags: _parseJournalTags(tags.text)); if (dialogContext.mounted) Navigator.pop(dialogContext, true); } catch (error) { if (dialogContext.mounted) showOrvaError(dialogContext, error); } }, child: const Text('Salvar entrada'))],
  )));
  content.dispose(); tags.dispose();
  return result;
}

String _dateLabel(String key) { try { return DateFormat('EEEE, d MMMM yyyy', 'pt_BR').format(DateTime.parse(key)); } catch (_) { return key; } }
List<String> _decodeTags(Object? value) { try { return (jsonDecode(value as String? ?? '[]') as List<dynamic>).whereType<String>().toList(); } catch (_) { return []; } }
List<String> _parseJournalTags(String value) => value.split(',').map((item) => item.trim()).where((item) => item.isNotEmpty).toSet().toList();

class _MoodChip extends StatelessWidget {
  const _MoodChip({required this.mood});
  final String mood;
  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5), decoration: BoxDecoration(color: OrvaColors.terracotta.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)), child: Text(mood, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: OrvaColors.terracotta)));
}
class _JournalTag extends StatelessWidget {
  const _JournalTag({required this.label});
  final String label;
  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5), decoration: BoxDecoration(color: OrvaColors.terracotta.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(7)), child: Text('#$label', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: OrvaColors.terracotta, fontSize: 12)));
}
