import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/orva_repository.dart';
import '../../core/theme/orva_theme.dart';
import '../../core/widgets/orva_widgets.dart';

class CategoriesPage extends ConsumerStatefulWidget {
  const CategoriesPage({super.key});
  @override
  ConsumerState<CategoriesPage> createState() => _CategoriesPageState();
}

class _CategoriesPageState extends ConsumerState<CategoriesPage> {
  String _scope = 'goals';
  bool _loading = true;
  List<Map<String, Object?>> _categories = [];

  @override
  void initState() { super.initState(); _load(); }
  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final rows = await ref.read(repositoryProvider).getCategories(scope: _scope);
      if (!mounted) return;
      setState(() { _categories = rows; _loading = false; });
    } catch (error) { if (mounted) { setState(() => _loading = false); showOrvaError(context, error); } }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Categorias')),
    floatingActionButton: FloatingActionButton.extended(onPressed: () async { await showCategoryEditor(context, ref, scope: _scope); await _load(); }, icon: const Icon(Icons.add), label: const Text('Nova categoria')),
    body: SafeArea(child: Column(children: [
      Padding(padding: const EdgeInsets.fromLTRB(20, 8, 20, 14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Personalize os nomes que organizam suas informações.', style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: 14),
        SegmentedButton<String>(segments: const [ButtonSegment(value: 'goals', label: Text('Metas')), ButtonSegment(value: 'routine', label: Text('Rotina')), ButtonSegment(value: 'hobbies', label: Text('Hobbies'))], selected: {_scope}, showSelectedIcon: false, onSelectionChanged: (selected) { setState(() => _scope = selected.first); _load(); }),
      ])),
      Expanded(child: _loading ? const Center(child: CircularProgressIndicator()) : _categories.isEmpty
        ? ListView(children: [OrvaEmptyState(icon: Icons.label_outline_rounded, title: 'Nenhuma categoria salva', message: 'As categorias que você digitar em metas, rotina ou hobbies também são registradas aqui. Você pode criar sugestões antes de usá-las.', actionLabel: 'Criar categoria', onAction: () async { await showCategoryEditor(context, ref, scope: _scope); await _load(); })])
        : RefreshIndicator(onRefresh: _load, child: ListView.separated(padding: const EdgeInsets.fromLTRB(20, 4, 20, 100), itemCount: _categories.length, separatorBuilder: (_, _) => const SizedBox(height: 8), itemBuilder: (context, index) {
          final category = _categories[index];
          return OrvaSurface(child: Row(children: [
            Container(width: 38, height: 38, decoration: BoxDecoration(color: OrvaColors.primary.withValues(alpha: 0.09), borderRadius: BorderRadius.circular(11)), child: const Icon(Icons.label_outline_rounded, color: OrvaColors.primary)),
            const SizedBox(width: 12),
            Expanded(child: Text('${category['name']}', style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600))),
            IconButton(tooltip: 'Renomear categoria', onPressed: () async { await showCategoryEditor(context, ref, category: category, scope: _scope); await _load(); }, icon: const Icon(Icons.edit_outlined)),
            IconButton(tooltip: 'Remover do catálogo', onPressed: () async {
              final ok = await confirmAction(context, title: 'Remover categoria?', message: 'A categoria deixará de aparecer neste catálogo. Rótulos já gravados nos registros serão preservados para não alterar seus dados.', actionLabel: 'Remover', destructive: true);
              if (ok) { await ref.read(repositoryProvider).deleteCategory(category['id'] as String); await _load(); }
            }, icon: const Icon(Icons.delete_outline_rounded, color: OrvaColors.error)),
          ]));
        }))),
    ])),
  );
}

Future<bool?> showCategoryEditor(BuildContext context, WidgetRef ref, {Map<String, Object?>? category, required String scope}) async {
  final repository = ref.read(repositoryProvider);
  final name = TextEditingController(text: category?['name'] as String? ?? '');
  final key = GlobalKey<FormState>();
  final result = await showDialog<bool>(context: context, builder: (dialogContext) => AlertDialog(
    title: Text(category == null ? 'Nova categoria' : 'Renomear categoria'),
    content: SizedBox(width: 400, child: Form(key: key, child: Column(mainAxisSize: MainAxisSize.min, children: [
      TextFormField(controller: name, autofocus: true, decoration: const InputDecoration(labelText: 'Nome *'), validator: (value) => value == null || value.trim().isEmpty ? 'Informe um nome.' : null),
      const SizedBox(height: 10),
      Align(alignment: Alignment.centerLeft, child: Text('Área: ${_scopeLabel(scope)}', style: Theme.of(context).textTheme.bodySmall)),
      if (category != null) ...[
        const SizedBox(height: 8),
        Align(alignment: Alignment.centerLeft, child: Text('Renomear também atualiza o rótulo dos registros associados a esta categoria.', style: Theme.of(context).textTheme.bodySmall)),
      ],
    ]))),
    actions: [TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancelar')), FilledButton(onPressed: () async { if (!key.currentState!.validate()) return; try { await repository.saveCategory(id: category?['id'] as String?, name: name.text, scope: scope); if (dialogContext.mounted) Navigator.pop(dialogContext, true); } catch (error) { if (dialogContext.mounted) showOrvaError(dialogContext, error); } }, child: const Text('Salvar'))],
  ));
  name.dispose();
  return result;
}

String _scopeLabel(String scope) => switch (scope) { 'goals' => 'Metas', 'routine' => 'Rotina', 'hobbies' => 'Hobbies', _ => 'Geral' };
