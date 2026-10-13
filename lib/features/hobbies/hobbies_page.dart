import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/database/orva_repository.dart';
import '../../core/theme/orva_theme.dart';
import '../../core/widgets/orva_widgets.dart';

class HobbiesPage extends ConsumerStatefulWidget {
  const HobbiesPage({super.key});
  @override
  ConsumerState<HobbiesPage> createState() => _HobbiesPageState();
}

class _HobbiesPageState extends ConsumerState<HobbiesPage> {
  bool _loading = true;
  List<Map<String, Object?>> _hobbies = [];
  bool _showArchived = false;

  @override
  void initState() { super.initState(); _load(); }
  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final hobbies = await ref.read(repositoryProvider).getWeeklyHobbyMinutes(date: DateTime.now(), includeArchived: _showArchived);
      if (!mounted) return;
      setState(() { _hobbies = hobbies; _loading = false; });
    } catch (error) { if (mounted) { setState(() => _loading = false); showOrvaError(context, error); } }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(heroTag: 'hobbies-create', onPressed: () async { await showHobbyEditor(context, ref); await _load(); }, icon: const Icon(Icons.add), label: const Text('Novo hobby')),
      body: SafeArea(child: Column(children: [
        const OrvaPageHeader(title: 'Hobbies', subtitle: 'Tempo realizado, metas semanais e histórico pessoal.'),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: SegmentedButton<bool>(segments: const [ButtonSegment(value: false, label: Text('Ativos')), ButtonSegment(value: true, label: Text('Arquivados'))], selected: {_showArchived}, showSelectedIcon: false, onSelectionChanged: (value) { setState(() => _showArchived = value.first); _load(); })),
        const SizedBox(height: 10),
        Expanded(child: _loading ? const Center(child: CircularProgressIndicator()) : _hobbies.isEmpty
          ? ListView(children: [OrvaEmptyState(icon: Icons.sports_esports_outlined, title: _showArchived ? 'Nenhum hobby arquivado' : 'Abra espaço para o que você gosta', message: _showArchived ? 'Hobbies arquivados aparecerão aqui com seu histórico de sessões.' : 'Cadastre um hobby para começar a registrar suas sessões e acompanhar o tempo investido.', actionLabel: _showArchived ? null : 'Adicionar hobby', onAction: _showArchived ? null : () async { await showHobbyEditor(context, ref); await _load(); })])
          : RefreshIndicator(onRefresh: _load, child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 100),
              itemCount: _hobbies.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final hobby = _hobbies[index];
                final actual = intValue(hobby['actual_minutes']);
                final target = hobby['weekly_target_minutes'] as num?;
                final ratio = target == null || target == 0 ? null : (actual / target.toDouble()).clamp(0.0, 1.0);
                final targetMinutes = target?.toInt();
                final isArchived = intValue(hobby['is_active']) == 0;
                return OrvaSurface(onTap: () async { await _showHobbyDetails(hobby); await _load(); }, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Container(width: 44, height: 44, decoration: BoxDecoration(color: OrvaColors.terracotta.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(13)), child: const Icon(Icons.sports_esports_outlined, color: OrvaColors.terracotta)),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('${hobby['name']}', style: Theme.of(context).textTheme.titleMedium), if ((hobby['category'] as String?)?.isNotEmpty == true) Text('${hobby['category']}', style: Theme.of(context).textTheme.bodySmall)])),
                    Text(formatMinutes(actual), style: Theme.of(context).textTheme.titleMedium?.copyWith(color: OrvaColors.terracotta)),
                    PopupMenuButton<String>(onSelected: (choice) async {
                      if (choice == 'edit') { await showHobbyEditor(context, ref, hobby: hobby); await _load(); }
                      if (choice == 'session') { await showHobbySessionEditor(context, ref, hobby); await _load(); }
                      if (choice == 'archive') {
                        final ok = await confirmAction(context, title: 'Arquivar hobby?', message: 'O hobby sairá da lista ativa. O histórico de sessões será preservado.', actionLabel: 'Arquivar');
                        if (ok) { await ref.read(repositoryProvider).archiveHobby(hobby['id'] as String); await _load(); }
                      }
                      if (choice == 'restore') { await ref.read(repositoryProvider).setHobbyActive(hobby['id'] as String, true); await _load(); }
                      if (choice == 'delete') {
                        final ok = await confirmAction(context, title: 'Excluir hobby e sessões?', message: 'O hobby e todos os registros de tempo associados serão removidos permanentemente.', actionLabel: 'Excluir', destructive: true);
                        if (ok) { await ref.read(repositoryProvider).deleteHobby(hobby['id'] as String); await _load(); }
                      }
                    }, itemBuilder: (_) => [
                      if (!isArchived) const PopupMenuItem(value: 'session', child: Text('Registrar sessão')),
                      const PopupMenuItem(value: 'edit', child: Text('Editar')),
                      if (isArchived) const PopupMenuItem(value: 'restore', child: Text('Restaurar hobby')),
                      if (!isArchived) const PopupMenuItem(value: 'archive', child: Text('Arquivar')),
                      const PopupMenuItem(value: 'delete', child: Text('Excluir hobby e sessões')),
                    ]),
                  ]),
                  if ((hobby['description'] as String?)?.isNotEmpty == true) ...[const SizedBox(height: 10), Text('${hobby['description']}', style: Theme.of(context).textTheme.bodyMedium)],
                  const SizedBox(height: 16),
                  if (ratio != null && target != null && targetMinutes != null) ...[
                    Row(children: [Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(5), child: LinearProgressIndicator(value: ratio, minHeight: 6, color: OrvaColors.terracotta, backgroundColor: OrvaColors.terracottaLight))), const SizedBox(width: 10), Text('${((actual / target.toDouble()) * 100).round()}% da meta', style: Theme.of(context).textTheme.bodySmall)]),
                    const SizedBox(height: 7),
                    Text('Meta semanal: ${formatMinutes(targetMinutes)}', style: Theme.of(context).textTheme.bodySmall),
                  ] else Text('Sem meta semanal definida · toque para ver o histórico', style: Theme.of(context).textTheme.bodySmall),
                ]));
              },
            ))),
      ])),
    );
  }

  Future<void> _showHobbyDetails(Map<String, Object?> hobby) async {
    final repo = ref.read(repositoryProvider);
    var sessions = await repo.getHobbySessions(hobby['id'] as String);
    if (!mounted) return;
    await showModalBottomSheet<void>(context: context, isScrollControlled: true, showDragHandle: true, builder: (sheetContext) => StatefulBuilder(builder: (context, setSheetState) => SafeArea(child: Padding(
      padding: EdgeInsets.fromLTRB(20, 4, 20, MediaQuery.of(context).viewInsets.bottom + 24),
      child: SizedBox(height: MediaQuery.of(context).size.height * 0.72, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('${hobby['name']}', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 4),
        Text('As sessões registradas são tempo realizado; metas de tempo não medem domínio da habilidade.', style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 14),
        Row(children: [Expanded(child: Text('Histórico de sessões', style: Theme.of(context).textTheme.titleMedium)), if (intValue(hobby['is_active']) == 1) FilledButton.icon(onPressed: () async { await showHobbySessionEditor(context, ref, hobby); sessions = await repo.getHobbySessions(hobby['id'] as String); if (sheetContext.mounted) setSheetState(() {}); }, icon: const Icon(Icons.add, size: 18), label: const Text('Registrar'))]),
        const SizedBox(height: 8),
        if (sessions.isEmpty) const Expanded(child: OrvaEmptyState(icon: Icons.timer_outlined, title: 'Nenhuma sessão registrada', message: 'Registre a duração de uma atividade quando ela acontecer.', compact: true)) else Expanded(child: ListView.separated(itemCount: sessions.length, separatorBuilder: (_, _) => const Divider(height: 1), itemBuilder: (context, index) {
          final session = sessions[index];
          return ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.timer_outlined, color: OrvaColors.terracotta),
            title: Text(formatMinutes(intValue(session['duration_minutes']))),
            subtitle: Text('${session['session_date']}${(session['note'] as String?)?.isNotEmpty == true ? ' · ${session['note']}' : ''}'),
            trailing: Wrap(children: [
              if (intValue(hobby['is_active']) == 1) IconButton(tooltip: 'Editar sessão', icon: const Icon(Icons.edit_outlined), onPressed: () async {
                await showHobbySessionEditor(context, ref, hobby, session: session);
                sessions = await repo.getHobbySessions(hobby['id'] as String);
                if (sheetContext.mounted) setSheetState(() {});
              }),
              IconButton(tooltip: 'Excluir sessão', icon: const Icon(Icons.delete_outline, color: OrvaColors.error), onPressed: () async {
                final ok = await confirmAction(context, title: 'Excluir sessão?', message: 'Este registro de tempo será removido.', actionLabel: 'Excluir', destructive: true);
                if (ok) { await repo.deleteHobbySession(session['id'] as String); sessions = await repo.getHobbySessions(hobby['id'] as String); if (sheetContext.mounted) setSheetState(() {}); }
              }),
            ]),
          );
        })),
        const SizedBox(height: 8),
        SizedBox(width: double.infinity, child: OutlinedButton(onPressed: () => Navigator.pop(sheetContext), child: const Text('Fechar'))),
      ])),
    ))));
  }
}

Future<bool?> showHobbyEditor(BuildContext context, WidgetRef ref, {Map<String, Object?>? hobby}) async {
  final repo = ref.read(repositoryProvider);
  final name = TextEditingController(text: hobby?['name'] as String? ?? '');
  final description = TextEditingController(text: hobby?['description'] as String? ?? '');
  final category = TextEditingController(text: hobby?['category'] as String? ?? '');
  final target = TextEditingController(text: hobby?['weekly_target_minutes']?.toString() ?? '');
  final key = GlobalKey<FormState>();
  final result = await showDialog<bool>(context: context, builder: (dialogContext) => AlertDialog(title: Text(hobby == null ? 'Novo hobby' : 'Editar hobby'), content: SizedBox(width: 420, child: Form(key: key, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
    TextFormField(controller: name, autofocus: true, decoration: const InputDecoration(labelText: 'Nome *'), validator: (value) => value == null || value.trim().isEmpty ? 'Informe o nome.' : null),
    const SizedBox(height: 12), TextFormField(controller: description, decoration: const InputDecoration(labelText: 'Descrição (opcional)'), maxLines: 3),
    const SizedBox(height: 12), TextFormField(controller: category, decoration: const InputDecoration(labelText: 'Categoria personalizada (opcional)')),
    const SizedBox(height: 12), TextFormField(controller: target, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Meta de tempo semanal em minutos (opcional)'), validator: (value) => value != null && value.trim().isNotEmpty && int.tryParse(value) == null ? 'Use minutos inteiros.' : null),
    const SizedBox(height: 6), Align(alignment: Alignment.centerLeft, child: Text('Exemplo de unidade: 120 minutos. O progresso usa apenas sessões que você registrar.', style: Theme.of(context).textTheme.bodySmall)),
  ])))), actions: [TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancelar')), FilledButton(onPressed: () async { if (!key.currentState!.validate()) return; try { await repo.saveHobby(id: hobby?['id'] as String?, name: name.text, description: description.text, category: category.text, weeklyTargetMinutes: target.text.trim().isEmpty ? null : int.parse(target.text)); if (dialogContext.mounted) Navigator.pop(dialogContext, true); } catch (error) { if (dialogContext.mounted) showOrvaError(dialogContext, error); } }, child: const Text('Salvar'))]));
  name.dispose(); description.dispose(); category.dispose(); target.dispose();
  return result;
}

Future<bool?> showHobbySessionEditor(BuildContext context, WidgetRef ref, Map<String, Object?> hobby, {Map<String, Object?>? session}) async {
  final repo = ref.read(repositoryProvider);
  final duration = TextEditingController(text: session?['duration_minutes']?.toString() ?? '');
  final note = TextEditingController(text: session?['note'] as String? ?? '');
  DateTime date = DateTime.tryParse(session?['session_date'] as String? ?? '') ?? DateTime.now();
  final key = GlobalKey<FormState>();
  final result = await showDialog<bool>(context: context, builder: (dialogContext) => StatefulBuilder(builder: (context, setState) => AlertDialog(title: Text(session == null ? 'Registrar sessão · ${hobby['name']}' : 'Editar sessão · ${hobby['name']}'), content: SizedBox(width: 420, child: Form(key: key, child: Column(mainAxisSize: MainAxisSize.min, children: [
    TextFormField(controller: duration, autofocus: true, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Duração em minutos *', hintText: 'Ex.: 45'), validator: (value) => int.tryParse(value ?? '') == null || int.parse(value!) <= 0 ? 'Informe minutos maiores que zero.' : null),
    const SizedBox(height: 12),
    OutlinedButton.icon(onPressed: () async { final d = await showDatePicker(context: context, initialDate: date, firstDate: DateTime(2000), lastDate: DateTime(2100)); if (d != null) setState(() => date = d); }, icon: const Icon(Icons.calendar_today_outlined), label: Text(DateFormat('dd/MM/yyyy').format(date))),
    const SizedBox(height: 12), TextFormField(controller: note, decoration: const InputDecoration(labelText: 'Observação opcional'), maxLines: 2),
  ]))), actions: [TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancelar')), FilledButton(onPressed: () async { if (!key.currentState!.validate()) return; try { await repo.addHobbySession(id: session?['id'] as String?, hobbyId: hobby['id'] as String, sessionDate: repo.dateKey(date), durationMinutes: int.parse(duration.text), note: note.text); if (dialogContext.mounted) Navigator.pop(dialogContext, true); } catch (error) { if (dialogContext.mounted) showOrvaError(dialogContext, error); } }, child: Text(session == null ? 'Salvar sessão' : 'Atualizar sessão'))])));
  duration.dispose(); note.dispose();
  return result;
}
