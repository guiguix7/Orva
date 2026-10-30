import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/database/orva_repository.dart';
import '../../core/database/executions_repository.dart';
import '../../core/widgets/orva_widgets.dart';

class ExecutionsPage extends ConsumerStatefulWidget {
  const ExecutionsPage({super.key});
  @override
  ConsumerState<ExecutionsPage> createState() => _ExecutionsPageState();
}

class _ExecutionsPageState extends ConsumerState<ExecutionsPage> {
  bool _loading = true;
  List<Map<String, Object?>> _items = [];
  // stopwatch
  Stopwatch? _stopwatch;
  Timer? _timer;
  int _elapsedSeconds = 0;
  bool _running = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final items = await ref.read(repositoryProvider).getExecutions(from: DateTime.now(), to: DateTime.now());
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

  void _startStopwatch() {
    _stopwatch = Stopwatch()..start();
    _running = true;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _elapsedSeconds = _stopwatch!.elapsed.inSeconds);
    });
    setState(() {});
  }

  void _pauseStopwatch() {
    _stopwatch?.stop();
    _running = false;
    _timer?.cancel();
    setState(() {});
  }

  void _resumeStopwatch() {
    _stopwatch?.start();
    _running = true;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _elapsedSeconds = _stopwatch!.elapsed.inSeconds);
    });
    setState(() {});
  }

  Future<void> _finishStopwatch() async {
    _stopwatch?.stop();
    _timer?.cancel();
    final seconds = _stopwatch?.elapsed.inSeconds ?? _elapsedSeconds;
    final minutes = (seconds / 60).ceil().clamp(1, 100000);
    _running = false;
    _elapsedSeconds = 0;
    _stopwatch = null;
    setState(() {});

    final titleCtrl = TextEditingController();
    final categoryCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Registrar tempo'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('Tempo decorrido: ${_format(seconds)}'),
          const SizedBox(height: 8),
          TextField(controller: titleCtrl, autofocus: true, decoration: const InputDecoration(labelText: 'Título *')),
          const SizedBox(height: 8),
          TextField(controller: categoryCtrl, decoration: const InputDecoration(labelText: 'Categoria')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialog, false), child: const Text('Descartar')),
          FilledButton(onPressed: () => Navigator.pop(dialog, true), child: const Text('Salvar')),
        ],
      ),
    );
    if (ok != true) {
      return;
    }
    try {
      final now = DateTime.now();
      await ref.read(repositoryProvider).saveExecution(
        title: titleCtrl.text,
        category: categoryCtrl.text,
        durationMinutes: minutes,
        startedAt: now.subtract(Duration(seconds: seconds)),
        endedAt: now,
        source: 'timer',
        referenceDate: now,
      );
      await _load();
    } catch (error) {
      if (mounted) showOrvaError(context, error);
    } finally {
      titleCtrl.dispose();
      categoryCtrl.dispose();
    }
  }

  String _format(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  Future<void> _manual() async {
    final titleCtrl = TextEditingController();
    final categoryCtrl = TextEditingController();
    final minutesCtrl = TextEditingController(text: '25');
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Registrar execução manual'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: titleCtrl, autofocus: true, decoration: const InputDecoration(labelText: 'Título *')),
          const SizedBox(height: 8),
          TextField(controller: categoryCtrl, decoration: const InputDecoration(labelText: 'Categoria')),
          const SizedBox(height: 8),
          TextField(controller: minutesCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Minutos')),
        ]),
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
      final minutes = int.tryParse(minutesCtrl.text.trim()) ?? 0;
      final now = DateTime.now();
      await ref.read(repositoryProvider).saveExecution(
        title: titleCtrl.text,
        category: categoryCtrl.text,
        durationMinutes: minutes <= 0 ? 1 : minutes,
        startedAt: now,
        source: 'manual',
        referenceDate: now,
      );
      await _load();
    } catch (error) {
      if (mounted) showOrvaError(context, error);
    } finally {
      titleCtrl.dispose();
      categoryCtrl.dispose();
      minutesCtrl.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Execuções reais')),
      floatingActionButton: FloatingActionButton(onPressed: _manual, child: const Icon(Icons.add)),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(children: [
                Text(_format(_elapsedSeconds), style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: 8),
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  if (!_running && _elapsedSeconds == 0)
                    FilledButton.icon(onPressed: _startStopwatch, icon: const Icon(Icons.play_arrow), label: const Text('Iniciar'))
                  else if (_running)
                    FilledButton.icon(onPressed: _pauseStopwatch, icon: const Icon(Icons.pause), label: const Text('Pausar'))
                  else ...[
                    FilledButton.icon(onPressed: _resumeStopwatch, icon: const Icon(Icons.play_arrow), label: const Text('Continuar')),
                    const SizedBox(width: 8),
                    FilledButton.icon(onPressed: _finishStopwatch, icon: const Icon(Icons.stop), label: const Text('Encerrar')),
                  ],
                  if (_elapsedSeconds > 0 && !_running) ...[
                    const SizedBox(width: 8),
                    OutlinedButton.icon(onPressed: () {
                      _stopwatch?.stop();
                      _timer?.cancel();
                      _elapsedSeconds = 0;
                      _stopwatch = null;
                      setState(() {});
                    }, icon: const Icon(Icons.delete_outline), label: const Text('Descartar')),
                  ],
                ]),
              ]),
            ),
          ),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _items.isEmpty
                  ? OrvaEmptyState(icon: Icons.timer_outlined, title: 'Nenhuma execução hoje', message: 'Use o cronômetro ou registre manualmente.', actionLabel: 'Registrar', onAction: _manual)
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _items.length,
                      itemBuilder: (context, index) {
                        final e = _items[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            title: Text(e['title'] as String),
                            subtitle: Text('${e['category'] ?? ''} • ${formatMinutes(e['duration_minutes'] as int)} • ${DateFormat('HH:mm').format(DateTime.parse(e['started_at'] as String))}'),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete_outline),
                              onPressed: () async {
                                final ok = await confirmAction(context, title: 'Excluir?', message: 'Remover este registro?', actionLabel: 'Excluir', destructive: true);
                                if (ok) {
                                  await ref.read(repositoryProvider).deleteExecution(e['id'] as String);
                                  await _load();
                                }
                              },
                            ),
                          ),
                        );
                      },
                    ),
        ),
      ]),
    );
  }
}
