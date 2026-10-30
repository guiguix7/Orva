import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/orva_repository.dart';
import '../../core/database/habits_repository.dart';
import '../../core/widgets/orva_widgets.dart';

class HabitsPage extends ConsumerStatefulWidget {
  const HabitsPage({super.key});
  @override
  ConsumerState<HabitsPage> createState() => _HabitsPageState();
}

class _HabitsPageState extends ConsumerState<HabitsPage> {
  bool _loading = true;
  List<Map<String, Object?>> _habits = [];
  final Map<String, double> _today = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final repo = ref.read(repositoryProvider);
      final habits = await repo.getHabits();
      final now = DateTime.now();
      final totals = <String, double>{};
      for (final h in habits) {
        final id = h['id'] as String;
        final logs = await repo.getHabitLogs(id, from: now, to: now);
        totals[id] = logs.isEmpty ? 0 : (logs.first['quantity'] as num).toDouble();
      }
      if (!mounted) return;
      setState(() {
        _habits = habits;
        _today
          ..clear()
          ..addAll(totals);
        _loading = false;
      });
    } catch (error) {
      if (mounted) {
        setState(() => _loading = false);
        showOrvaError(context, error);
      }
    }
  }

  Future<void> _edit([Map<String, Object?>? habit]) async {
    final name = TextEditingController(text: habit?['name'] as String? ?? '');
    final unit = TextEditingController(text: habit?['unit'] as String? ?? 'vezes');
    final target = TextEditingController(text: habit?['target_value']?.toString() ?? '');
    final category = TextEditingController(text: habit?['category'] as String? ?? '');
    if (!mounted) {
      name.dispose();
      unit.dispose();
      target.dispose();
      category.dispose();
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text(habit == null ? 'Novo hábito' : 'Editar hábito'),
        content: SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(controller: name, autofocus: true, decoration: const InputDecoration(labelText: 'Nome *')),
              const SizedBox(height: 8),
              TextField(controller: unit, decoration: const InputDecoration(labelText: 'Unidade')),
              const SizedBox(height: 8),
              TextField(controller: target, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Meta (opcional)')),
              const SizedBox(height: 8),
              TextField(controller: category, decoration: const InputDecoration(labelText: 'Categoria')),
            ]),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialog, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(dialog, true), child: const Text('Salvar')),
        ],
      ),
    );
    if (ok != true) {
      return;
    }
    try {
      final repo = ref.read(repositoryProvider);
      await repo.saveHabit(
        id: habit?['id'] as String?,
        name: name.text,
        unit: unit.text.trim().isEmpty ? 'vezes' : unit.text,
        targetValue: double.tryParse(target.text.trim().replaceAll(',', '.')),
        category: category.text,
      );
      await _load();
    } catch (error) {
      if (mounted) showOrvaError(context, error);
    } finally {
      name.dispose();
      unit.dispose();
      target.dispose();
      category.dispose();
    }
  }

  Future<void> _register(Map<String, Object?> habit) async {
    final ctrl = TextEditingController(text: (_today[habit['id'] as String] ?? 0).toString());
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text('Registrar ${habit['name']}'),
        content: TextField(controller: ctrl, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: habit['unit'] as String? ?? 'quantidade')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialog, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(dialog, true), child: const Text('Salvar')),
        ],
      ),
    );
    if (ok != true) {
      return;
    }
    try {
      final qty = double.tryParse(ctrl.text.trim().replaceAll(',', '.')) ?? 0;
      await ref.read(repositoryProvider).logHabit(habitId: habit['id'] as String, date: DateTime.now(), quantity: qty);
      await _load();
    } catch (error) {
      if (mounted) showOrvaError(context, error);
    } finally {
      ctrl.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Hábitos')),
      floatingActionButton: FloatingActionButton(onPressed: () => _edit(), child: const Icon(Icons.add)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _habits.isEmpty
              ? OrvaEmptyState(icon: Icons.track_changes_outlined, title: 'Nenhum hábito', message: 'Crie hábitos quantitativos com unidades personalizadas.', actionLabel: 'Criar hábito', onAction: () => _edit())
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _habits.length,
                  itemBuilder: (context, index) {
                    final h = _habits[index];
                    final id = h['id'] as String;
                    final today = _today[id] ?? 0;
                    final target = (h['target_value'] as num?)?.toDouble();
                    final progress = target == null || target <= 0 ? null : (today / target).clamp(0, 1).toDouble();
                    return Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      child: ListTile(
                        title: Text(h['name'] as String),
                        subtitle: Text('${today.toStringAsFixed(today.truncateToDouble() == today ? 0 : 1)} ${h['unit']} hoje${target != null ? ' de ${target.toStringAsFixed(target.truncateToDouble() == target ? 0 : 1)}' : ''}'),
                        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                          if (progress != null) SizedBox(width: 44, child: LinearProgressIndicator(value: progress)),
                          IconButton(icon: const Icon(Icons.add_circle_outline), onPressed: () => _register(h)),
                          IconButton(icon: const Icon(Icons.edit_outlined), onPressed: () => _edit(h)),
                        ]),
                      ),
                    );
                  },
                ),
    );
  }
}
