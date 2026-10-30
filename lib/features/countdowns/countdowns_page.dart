import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/database/orva_repository.dart';
import '../../core/database/countdowns_repository.dart';
import '../../core/widgets/orva_widgets.dart';

class CountdownsPage extends ConsumerStatefulWidget {
  const CountdownsPage({super.key});
  @override
  ConsumerState<CountdownsPage> createState() => _CountdownsPageState();
}

class _CountdownsPageState extends ConsumerState<CountdownsPage> {
  bool _loading = true;
  List<Map<String, Object?>> _items = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final items = await ref.read(repositoryProvider).getCountdowns();
      if (!mounted) return;
      setState(() {
        _items = items;
        _loading = false;
      });
    } catch (error) {
      if (mounted) {
        setState(() => _loading = false);
        showOrvaError(context, error);
      }
    }
  }

  Future<void> _edit([Map<String, Object?>? item]) async {
    final title = TextEditingController(text: item?['title'] as String? ?? '');
    final category = TextEditingController(text: item?['category'] as String? ?? '');
    final description = TextEditingController(text: item?['description'] as String? ?? '');
    var date = DateTime.tryParse(item?['target_date'] as String? ?? '') ?? DateTime.now();
    if (!mounted) {
      title.dispose();
      category.dispose();
      description.dispose();
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialog) => StatefulBuilder(builder: (context, setDialog) => AlertDialog(
        title: Text(item == null ? 'Nova contagem regressiva' : 'Editar contagem'),
        content: SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(controller: title, autofocus: true, decoration: const InputDecoration(labelText: 'Título *')),
              const SizedBox(height: 8),
              TextField(controller: category, decoration: const InputDecoration(labelText: 'Categoria')),
              const SizedBox(height: 8),
              TextField(controller: description, decoration: const InputDecoration(labelText: 'Descrição')),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(child: Text(DateFormat('dd/MM/yyyy').format(date))),
                TextButton(
                  onPressed: () async {
                    final picked = await showDatePicker(context: context, initialDate: date, firstDate: DateTime(2000), lastDate: DateTime(2100));
                    if (picked != null) setDialog(() => date = picked);
                  },
                  child: const Text('Escolher data'),
                ),
              ]),
            ]),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialog, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(dialog, true), child: const Text('Salvar')),
        ],
      )),
    );
    if (ok != true) {
      return;
    }
    try {
      await ref.read(repositoryProvider).saveCountdown(
        id: item?['id'] as String?,
        title: title.text,
        targetDate: date,
        category: category.text,
        description: description.text,
      );
      await _load();
    } catch (error) {
      if (mounted) showOrvaError(context, error);
    } finally {
      title.dispose();
      category.dispose();
      description.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.read(repositoryProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Contagens regressivas')),
      floatingActionButton: FloatingActionButton(onPressed: () => _edit(), child: const Icon(Icons.add)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty
              ? OrvaEmptyState(icon: Icons.event_outlined, title: 'Nenhuma contagem', message: 'Cadastre datas importantes para acompanhar.', actionLabel: 'Criar', onAction: () => _edit())
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _items.length,
                  itemBuilder: (context, index) {
                    final item = _items[index];
                    final target = DateTime.tryParse(item['target_date'] as String? ?? '') ?? DateTime.now();
                    final days = repo.countdownDaysRemaining(target);
                    String label;
                    if (days == 0) {
                      label = 'Hoje';
                    } else if (days > 0) {
                      label = '$days dia${days == 1 ? '' : 's'} restante${days == 1 ? '' : 's'}';
                    } else {
                      label = '${-days} dia${-days == 1 ? '' : 's'} atrás';
                    }
                    return Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      child: ListTile(
                        title: Text(item['title'] as String),
                        subtitle: Text('${DateFormat('dd/MM/yyyy').format(target)} • $label'),
                        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                          IconButton(icon: const Icon(Icons.edit_outlined), onPressed: () => _edit(item)),
                          IconButton(
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () async {
                              final ok = await confirmAction(context, title: 'Excluir?', message: 'Remover esta contagem?', actionLabel: 'Excluir', destructive: true);
                              if (ok) {
                                await ref.read(repositoryProvider).deleteCountdown(item['id'] as String);
                                await _load();
                              }
                            },
                          ),
                        ]),
                      ),
                    );
                  },
                ),
    );
  }
}
