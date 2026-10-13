import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/database/orva_repository.dart';
import '../../core/theme/orva_theme.dart';
import '../../core/widgets/orva_widgets.dart';

class NotesPage extends ConsumerStatefulWidget {
  const NotesPage({super.key});
  @override
  ConsumerState<NotesPage> createState() => _NotesPageState();
}

class _NotesPageState extends ConsumerState<NotesPage> {
  final _search = TextEditingController();
  bool _loading = true;
  List<Map<String, Object?>> _notes = [];

  @override
  void initState() { super.initState(); _load(); }
  @override
  void dispose() { _search.dispose(); super.dispose(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final notes = await ref.read(repositoryProvider).getNotes(search: _search.text);
      if (!mounted) return;
      setState(() { _notes = notes; _loading = false; });
    } catch (error) { if (mounted) { setState(() => _loading = false); showOrvaError(context, error); } }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    floatingActionButton: FloatingActionButton.extended(heroTag: 'notes-create', onPressed: () async { await showNoteEditor(context, ref); await _load(); }, icon: const Icon(Icons.add), label: const Text('Nova nota')),
    body: SafeArea(child: Column(children: [
      const OrvaPageHeader(title: 'Notas', subtitle: 'Ideias, informações e aprendizados — armazenados neste dispositivo.'),
      Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: TextField(controller: _search, onChanged: (_) => _load(), decoration: InputDecoration(prefixIcon: const Icon(Icons.search), hintText: 'Pesquisar título ou conteúdo', suffixIcon: _search.text.isEmpty ? null : IconButton(icon: const Icon(Icons.close), onPressed: () { _search.clear(); _load(); }),),)),
      const SizedBox(height: 14),
      Expanded(child: _loading ? const Center(child: CircularProgressIndicator()) : _notes.isEmpty
        ? ListView(children: [OrvaEmptyState(icon: Icons.edit_note_outlined, title: _search.text.isEmpty ? 'Seu espaço de ideias começa aqui' : 'Nenhuma nota encontrada', message: _search.text.isEmpty ? 'Guarde uma ideia assim que ela aparecer. Você pode editar o conteúdo depois.' : 'Tente outro termo de busca ou limpe o campo.', actionLabel: _search.text.isEmpty ? 'Escrever primeira nota' : null, onAction: _search.text.isEmpty ? () async { await showNoteEditor(context, ref); await _load(); } : null)])
        : RefreshIndicator(onRefresh: _load, child: ListView.separated(padding: const EdgeInsets.fromLTRB(20, 4, 20, 100), itemCount: _notes.length, separatorBuilder: (_, _) => const SizedBox(height: 10), itemBuilder: (context, index) {
          final note = _notes[index];
          final content = (note['content'] as String?) ?? '';
          final tags = _readTags(note['tags_json']);
          return OrvaSurface(onTap: () async { await showNoteEditor(context, ref, note: note); await _load(); }, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [Expanded(child: Text((note['title'] as String?)?.isNotEmpty == true ? note['title'] as String : 'Nota sem título', style: Theme.of(context).textTheme.titleMedium)), PopupMenuButton<String>(onSelected: (choice) async { if (choice == 'edit') { await showNoteEditor(context, ref, note: note); await _load(); } if (choice == 'delete') { final ok = await confirmAction(context, title: 'Excluir nota?', message: 'Esta nota será removida permanentemente deste dispositivo.', actionLabel: 'Excluir', destructive: true); if (ok) { await ref.read(repositoryProvider).deleteNote(note['id'] as String); await _load(); } } }, itemBuilder: (_) => const [PopupMenuItem(value: 'edit', child: Text('Editar')), PopupMenuItem(value: 'delete', child: Text('Excluir'))])]),
            if (content.isNotEmpty) ...[const SizedBox(height: 7), Text(content, maxLines: 3, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodyMedium)],
            if (tags.isNotEmpty) ...[const SizedBox(height: 12), Wrap(spacing: 6, runSpacing: 6, children: tags.map((tag) => _Tag(label: tag)).toList())],
            const SizedBox(height: 12),
            Row(children: [const Icon(Icons.history, size: 15, color: OrvaColors.tertiaryText), const SizedBox(width: 5), Text('Atualizada em ${DateFormat('dd/MM/yyyy · HH:mm').format(DateTime.parse(note['updated_at'] as String))}', style: Theme.of(context).textTheme.bodySmall)]),
          ]));
        }))),
    ])),
  );
}

Future<bool?> showNoteEditor(BuildContext context, WidgetRef ref, {Map<String, Object?>? note}) async {
  final repo = ref.read(repositoryProvider);
  final title = TextEditingController(text: note?['title'] as String? ?? '');
  final content = TextEditingController(text: note?['content'] as String? ?? '');
  final tags = TextEditingController(text: _readTags(note?['tags_json']).join(', '));
  final key = GlobalKey<FormState>();
  final result = await showDialog<bool>(context: context, builder: (dialogContext) => AlertDialog(
    title: Text(note == null ? 'Nova nota' : 'Editar nota'),
    content: SizedBox(width: 500, child: Form(key: key, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
      TextFormField(controller: title, autofocus: true, decoration: const InputDecoration(labelText: 'Título (opcional)'), textCapitalization: TextCapitalization.sentences),
      const SizedBox(height: 12),
      TextFormField(controller: content, minLines: 7, maxLines: 14, keyboardType: TextInputType.multiline, textCapitalization: TextCapitalization.sentences, decoration: const InputDecoration(labelText: 'Conteúdo', alignLabelWithHint: true, hintText: 'Registre uma ideia, informação ou aprendizado…'), validator: (value) => (value == null || value.trim().isEmpty) && title.text.trim().isEmpty ? 'Escreva um título ou conteúdo.' : null),
      const SizedBox(height: 12),
      TextFormField(controller: tags, decoration: const InputDecoration(labelText: 'Tags opcionais', hintText: 'Separadas por vírgula')),
      const SizedBox(height: 6),
      Align(alignment: Alignment.centerLeft, child: Text('O conteúdo fica salvo localmente e não é enviado para serviços externos.', style: Theme.of(context).textTheme.bodySmall)),
    ])))),
    actions: [TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancelar')), FilledButton(onPressed: () async { if (!key.currentState!.validate()) return; try { await repo.saveNote(id: note?['id'] as String?, title: title.text, content: content.text, tags: _parseTags(tags.text)); if (dialogContext.mounted) Navigator.pop(dialogContext, true); } catch (error) { if (dialogContext.mounted) showOrvaError(dialogContext, error); } }, child: const Text('Salvar nota'))],
  ));
  title.dispose(); content.dispose(); tags.dispose();
  return result;
}

List<String> _parseTags(String input) => input.split(',').map((value) => value.trim()).where((value) => value.isNotEmpty).toSet().toList();
List<String> _readTags(Object? value) { try { return (jsonDecode(value as String? ?? '[]') as List<dynamic>).whereType<String>().toList(); } catch (_) { return []; } }

class _Tag extends StatelessWidget {
  const _Tag({required this.label});
  final String label;
  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5), decoration: BoxDecoration(color: OrvaColors.primary.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(7)), child: Text('#$label', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: OrvaColors.primary, fontSize: 12)));
}
