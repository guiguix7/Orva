import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/database/orva_repository.dart';
import '../../core/database/nutrition_repository.dart';
import '../../core/theme/orva_theme.dart';
import '../../core/widgets/orva_widgets.dart';

const _mealTypes = <String, String>{
  'breakfast': 'Café da manhã',
  'lunch': 'Almoço',
  'dinner': 'Jantar',
  'snack': 'Lanche',
  'custom': 'Personalizada',
};

double? _parseNullableDouble(String value) {
  if (value.trim().isEmpty) return null;
  return double.tryParse(value.trim().replaceAll(',', '.'));
}

class NutritionPage extends ConsumerStatefulWidget {
  const NutritionPage({super.key});
  @override
  ConsumerState<NutritionPage> createState() => _NutritionPageState();
}

class _NutritionPageState extends ConsumerState<NutritionPage> {
  String _tab = 'today';
  DateTime _date = DateTime.now();
  bool _loading = true;
  List<Map<String, Object?>> _foods = [];
  List<Map<String, Object?>> _todayPlans = [];
  List<Map<String, Object?>> _allPlans = [];
  List<Map<String, Object?>> _consumptions = [];
  Map<String, Object?> _summary = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final repo = ref.read(repositoryProvider);
      final values = await Future.wait<Object?>([
        repo.getFoods(),
        repo.getMealPlansForDate(_date),
        repo.getMealPlans(),
        repo.getFoodConsumptionsForDate(_date),
        repo.getNutritionSummary(_date),
      ]);
      if (!mounted) return;
      setState(() {
        _foods = values[0] as List<Map<String, Object?>>;
        _todayPlans = values[1] as List<Map<String, Object?>>;
        _allPlans = values[2] as List<Map<String, Object?>>;
        _consumptions = values[3] as List<Map<String, Object?>>;
        _summary = values[4] as Map<String, Object?>;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _loading = false);
      showOrvaError(context, error);
    }
  }

  Future<void> _changeDate(int days) async {
    setState(() => _date = DateTime(_date.year, _date.month, _date.day + days));
    await _load();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked == null || !mounted) return;
    setState(() => _date = picked);
    await _load();
  }

  Future<void> _editFood([Map<String, Object?>? food]) async {
    final name = TextEditingController(text: food?['name'] as String? ?? '');
    final brand = TextEditingController(text: food?['brand'] as String? ?? '');
    final reference = TextEditingController(text: food == null ? '100' : '${food['reference_amount']}');
    final unit = TextEditingController(text: food?['reference_unit'] as String? ?? 'g');
    final calories = TextEditingController(text: food?['calories'] == null ? '' : '${food!['calories']}');
    final protein = TextEditingController(text: food?['protein_g'] == null ? '' : '${food!['protein_g']}');
    final carbs = TextEditingController(text: food?['carbohydrates_g'] == null ? '' : '${food!['carbohydrates_g']}');
    final fat = TextEditingController(text: food?['fat_g'] == null ? '' : '${food!['fat_g']}');
    final fibre = TextEditingController(text: food?['fibre_g'] == null ? '' : '${food!['fibre_g']}');
    final source = TextEditingController(text: food?['nutrition_source'] as String? ?? 'manual');
    final note = TextEditingController(text: food?['note'] as String? ?? '');
    if (!mounted) {
      for (final c in [name,brand,reference,unit,calories,protein,carbs,fat,fibre,source,note]) { c.dispose(); }
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text(food == null ? 'Cadastrar alimento' : 'Editar alimento'),
        content: SizedBox(
          width: 480,
          child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: name, autofocus: true, maxLength: 120, decoration: const InputDecoration(labelText: 'Nome *')),
            TextField(controller: brand, decoration: const InputDecoration(labelText: 'Marca (opcional)')),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: TextField(controller: reference, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Referência *'))),
              const SizedBox(width: 10),
              Expanded(child: DropdownButtonFormField<String>(
                value: unit.text,
                decoration: const InputDecoration(labelText: 'Unidade'),
                items: const [
                  DropdownMenuItem(value: 'g', child: Text('g')),
                  DropdownMenuItem(value: 'ml', child: Text('ml')),
                  DropdownMenuItem(value: 'porção', child: Text('porção')),
                  DropdownMenuItem(value: 'unidade', child: Text('unidade')),
                ],
                onChanged: (v) => unit.text = v ?? 'g',
              )),
            ]),
            const SizedBox(height: 4),
            Align(alignment: Alignment.centerLeft, child: Text('Composição por quantidade de referência. Deixe em branco o que não souber.', style: Theme.of(context).textTheme.bodySmall)),
            const SizedBox(height: 10),
            _nutritionField(calories, 'Calorias (kcal)'),
            _nutritionField(protein, 'Proteínas (g)'),
            _nutritionField(carbs, 'Carboidratos (g)'),
            _nutritionField(fat, 'Gorduras (g)'),
            _nutritionField(fibre, 'Fibras (g, opcional)'),
            TextField(controller: source, decoration: const InputDecoration(labelText: 'Origem dos valores', helperText: 'Ex.: rótulo, tabela oficial ou informado pelo usuário')),
            TextField(controller: note, maxLines: 2, decoration: const InputDecoration(labelText: 'Observações')),
          ])),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialog, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () {
            if (name.text.trim().isEmpty || (_parseNullableDouble(reference.text) ?? 0) <= 0) {
              showOrvaMessage(dialog, 'Informe o nome e uma quantidade de referência positiva.');
              return;
            }
            final values = [calories,protein,carbs,fat,fibre].map((c) => c.text.trim()).where((v) => v.isNotEmpty);
            if (values.any((v) => _parseNullableDouble(v) == null || _parseNullableDouble(v)! < 0)) {
              showOrvaMessage(dialog, 'Use valores nutricionais não negativos ou deixe o campo em branco.');
              return;
            }
            Navigator.pop(dialog, true);
          }, child: const Text('Salvar alimento')),
        ],
      ),
    );
    if (ok == true && mounted) {
      try {
        await ref.read(repositoryProvider).saveFood(
          id: food?['id'] as String?,
          name: name.text,
          brand: brand.text,
          referenceAmount: _parseNullableDouble(reference.text) ?? 100,
          referenceUnit: unit.text,
          calories: _parseNullableDouble(calories.text),
          proteinG: _parseNullableDouble(protein.text),
          carbohydratesG: _parseNullableDouble(carbs.text),
          fatG: _parseNullableDouble(fat.text),
          fibreG: _parseNullableDouble(fibre.text),
          nutritionSource: source.text,
          note: note.text,
        );
        await _load();
      } catch (error) { if (mounted) showOrvaError(context, error); }
    }
    for (final c in [name,brand,reference,unit,calories,protein,carbs,fat,fibre,source,note]) { c.dispose(); }
  }

  Widget _nutritionField(TextEditingController controller, String label) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(labelText: label),
    ),
  );

  Future<void> _editPlan([Map<String, Object?>? plan]) async {
    final title = TextEditingController(text: plan?['title'] as String? ?? '');
    final note = TextEditingController(text: plan?['note'] as String? ?? '');
    final durationController = TextEditingController(
      text: plan?['duration_minutes'] == null ? '' : '${plan!['duration_minutes']}',
    );
    var mealType = plan?['meal_type'] as String? ?? 'lunch';
    var recurrence = plan?['recurrence'] as String? ?? 'once';
    var plannedDate = DateTime.tryParse(plan?['planned_date'] as String? ?? '') ?? _date;
    var startDate = DateTime.tryParse(plan?['start_date'] as String? ?? '') ?? _date;
    var endDate = DateTime.tryParse(plan?['end_date'] as String? ?? '');
    int? minute = (plan?['planned_minute'] as num?)?.toInt();
    Set<int> weekdays = {};
    try {
      final raw = plan?['weekdays_json'] as String?;
      if (raw != null) {
        weekdays = (jsonDecode(raw) as List)
            .whereType<num>()
            .map((value) => value.toInt())
            .toSet();
      }
    } catch (_) {}
    if (weekdays.isEmpty) weekdays = {_date.weekday};
    if (!mounted) { title.dispose(); note.dispose(); durationController.dispose(); return; }
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialog) => StatefulBuilder(builder: (context, setDialog) => AlertDialog(
        title: Text(plan == null ? 'Planejar refeição' : 'Editar refeição planejada'),
        content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: title, autofocus: true, maxLength: 120, decoration: const InputDecoration(labelText: 'Nome da refeição *')),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: mealType,
            decoration: const InputDecoration(labelText: 'Tipo'),
            items: _mealTypes.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value))).toList(),
            onChanged: (v) => setDialog(() => mealType = v ?? 'custom'),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: recurrence,
            decoration: const InputDecoration(labelText: 'Repetição'),
            items: const [
              DropdownMenuItem(value: 'once', child: Text('Uma data')),
              DropdownMenuItem(value: 'daily', child: Text('Todos os dias')),
              DropdownMenuItem(value: 'weekly', child: Text('Dias da semana selecionados')),
            ],
            onChanged: (v) => setDialog(() => recurrence = v ?? 'once'),
          ),
          const SizedBox(height: 8),
          if (recurrence == 'once')
            OutlinedButton.icon(onPressed: () async {
              final d = await showDatePicker(context: context, initialDate: plannedDate, firstDate: DateTime(2000), lastDate: DateTime(2100));
              if (d != null) setDialog(() => plannedDate = d);
            }, icon: const Icon(Icons.calendar_today_outlined), label: Text('Data: ${DateFormat('dd/MM/yyyy','pt_BR').format(plannedDate)}'))
          else ...[
            OutlinedButton.icon(onPressed: () async {
              final d = await showDatePicker(context: context, initialDate: startDate, firstDate: DateTime(2000), lastDate: DateTime(2100));
              if (d != null) setDialog(() => startDate = d);
            }, icon: const Icon(Icons.event_outlined), label: Text('Começa em: ${DateFormat('dd/MM/yyyy','pt_BR').format(startDate)}')),
            if (recurrence == 'weekly')
              Wrap(spacing: 4, children: [
                for (final day in const [1,2,3,4,5,6,7])
                  FilterChip(
                    label: Text(['Seg','Ter','Qua','Qui','Sex','Sáb','Dom'][day-1]),
                    selected: weekdays.contains(day),
                    onSelected: (selected) => setDialog(() {
                      if (selected) { weekdays.add(day); } else { weekdays.remove(day); }
                    }),
                  ),
              ]),
            TextButton.icon(onPressed: () async {
              final d = await showDatePicker(context: context, initialDate: endDate ?? startDate.add(const Duration(days: 30)), firstDate: startDate, lastDate: DateTime(2100));
              if (d != null) setDialog(() => endDate = d);
            }, icon: const Icon(Icons.event_busy_outlined), label: Text(endDate == null ? 'Sem data final' : 'Termina em: ${DateFormat('dd/MM/yyyy','pt_BR').format(endDate!)}')),
            if (endDate != null) Align(alignment: Alignment.centerLeft, child: TextButton(onPressed: () => setDialog(() => endDate = null), child: const Text('Remover data final'))),
          ],
          OutlinedButton.icon(
            onPressed: () async {
              final initial = minute == null
                  ? const TimeOfDay(hour: 12, minute: 0)
                  : TimeOfDay(hour: minute! ~/ 60, minute: minute! % 60);
              final t = await showTimePicker(context: context, initialTime: initial);
              if (t != null) setDialog(() => minute = t.hour * 60 + t.minute);
            },
            icon: const Icon(Icons.schedule_outlined),
            label: Text(minute == null ? 'Adicionar horário' : 'Horário: ${formatClock(minute!)}'),
          ),
          if (minute != null)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: () => setDialog(() {
                  minute = null;
                  durationController.clear();
                }),
                child: const Text('Remover horário'),
              ),
            ),
          const SizedBox(height: 8),
          TextField(
            controller: durationController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Duração planejada (minutos, opcional)',
              helperText: 'Só entra na ocupação do tempo quando houver horário e duração.',
            ),
          ),
          const SizedBox(height: 8),
          TextField(controller: note, maxLines: 2, decoration: const InputDecoration(labelText: 'Observações')),
        ])),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialog, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () {
            if (title.text.trim().isEmpty) { showOrvaMessage(dialog, 'Informe o nome da refeição.'); return; }
            if ((recurrence == 'weekly') && weekdays.isEmpty) { showOrvaMessage(dialog, 'Selecione pelo menos um dia.'); return; }
            final rawDuration = durationController.text.trim();
            if (rawDuration.isNotEmpty) {
              final parsed = int.tryParse(rawDuration);
              if (parsed == null || parsed < 1 || parsed > 1440) {
                showOrvaMessage(dialog, 'A duração deve ser um número inteiro entre 1 e 1440 minutos.');
                return;
              }
              if (minute == null) {
                showOrvaMessage(dialog, 'Defina um horário inicial para usar a duração na ocupação.');
                return;
              }
              if (minute! + parsed > 1440) {
                showOrvaMessage(dialog, 'O intervalo não pode atravessar a meia-noite. Ajuste o horário ou a duração.');
                return;
              }
            }
            Navigator.pop(dialog, true);
          }, child: const Text('Salvar plano')),
        ],
      )),
    );
    if (ok == true && mounted) {
      try {
        await ref.read(repositoryProvider).saveMealPlan(
          id: plan?['id'] as String?,
          title: title.text,
          mealType: mealType,
          recurrence: recurrence,
          plannedDate: recurrence == 'once' ? _dateKey(plannedDate) : null,
          weekdays: recurrence == 'weekly' ? weekdays.toList() : const [],
          startDate: recurrence == 'once' ? null : _dateKey(startDate),
          endDate: recurrence == 'once' || endDate == null ? null : _dateKey(endDate!),
          plannedMinute: minute,
          durationMinutes: durationController.text.trim().isEmpty ? null : int.parse(durationController.text.trim()),
          note: note.text,
        );
        await _load();
      } catch (error) { if (mounted) showOrvaError(context, error); }
    }
    title.dispose();
    note.dispose();
    durationController.dispose();
  }

  Future<void> _addPlanItem(Map<String, Object?> plan) async {
    if (_foods.isEmpty) { showOrvaMessage(context, 'Cadastre pelo menos um alimento antes de adicionar itens ao plano.'); return; }
    var foodId = _foods.first['id'] as String;
    final quantity = TextEditingController(text: '${_foods.first['reference_amount']}');
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialog) => StatefulBuilder(builder: (context, setDialog) => AlertDialog(
        title: Text('Adicionar alimento ao plano'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          DropdownButtonFormField<String>(
            value: foodId,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Alimento'),
            items: _foods.map((f) => DropdownMenuItem(value: f['id'] as String, child: Text('${f['name']}', overflow: TextOverflow.ellipsis))).toList(),
            onChanged: (v) => setDialog(() {
              foodId = v ?? foodId;
              final food = _foods.where((item) => item['id'] == foodId).first;
              quantity.text = '${food['reference_amount']}';
            }),
          ),
          const SizedBox(height: 8),
          TextField(controller: quantity, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Quantidade na unidade de referência')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialog, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () {
            if ((_parseNullableDouble(quantity.text) ?? 0) <= 0) { showOrvaMessage(dialog, 'Informe uma quantidade positiva.'); return; }
            Navigator.pop(dialog, true);
          }, child: const Text('Adicionar')),
        ],
      )),
    );
    if (ok == true && mounted) {
      try {
        final items = await ref.read(repositoryProvider).getMealPlanItems(plan['id'] as String);
        await ref.read(repositoryProvider).addMealPlanItem(
          mealPlanId: plan['id'] as String,
          foodId: foodId,
          quantity: _parseNullableDouble(quantity.text)!,
          orderIndex: items.length,
        );
        await _load();
      } catch (error) { if (mounted) showOrvaError(context, error); }
    }
    quantity.dispose();
  }

  Future<void> _logConsumption([Map<String, Object?>? plan]) async {
    final repo = ref.read(repositoryProvider);
    final suggestions = <FoodQuantity>[];
    if (plan != null) {
      try {
        final plannedItems = await repo.getMealPlanItems(plan['id'] as String);
        for (final item in plannedItems) {
          final foodId = item['food_id'] as String?;
          final quantity = item['quantity'];
          if (foodId != null &&
              quantity is num &&
              _foods.any((food) => food['id'] == foodId)) {
            suggestions.add(FoodQuantity(foodId: foodId, quantity: quantity.toDouble()));
          }
        }
      } catch (error) {
        if (mounted) showOrvaError(context, error);
        return;
      }
    }
    if (!mounted) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => _FoodConsumptionDialog(
        repository: repo,
        foods: _foods,
        date: _date,
        plannedMeal: plan,
        suggestedItems: suggestions,
      ),
    );
    if (ok == true && mounted) await _load();
  }

  Future<void> _deleteFood(Map<String, Object?> food) async {
    final ok = await confirmAction(context, title: 'Excluir alimento do catálogo?', message: 'Os consumos e refeições planejadas anteriores preservam o nome e os valores nutricionais registrados; a referência ao catálogo será removida.', actionLabel: 'Excluir', destructive: true);
    if (!ok || !mounted) return;
    try { await ref.read(repositoryProvider).deleteFood(food['id'] as String); await _load(); }
    catch (error) { if (mounted) showOrvaError(context, error); }
  }

  Future<void> _deletePlan(Map<String, Object?> plan) async {
    final ok = await confirmAction(context, title: 'Excluir plano?', message: 'O plano e seus itens serão removidos. Registros de consumo já feitos não serão apagados.', actionLabel: 'Excluir', destructive: true);
    if (!ok || !mounted) return;
    try { await ref.read(repositoryProvider).deleteMealPlan(plan['id'] as String); await _load(); }
    catch (error) { if (mounted) showOrvaError(context, error); }
  }

  Future<void> _deleteConsumption(Map<String, Object?> meal) async {
    final ok = await confirmAction(context, title: 'Excluir registro de consumo?', message: 'Este registro alimentar será removido do histórico.', actionLabel: 'Excluir', destructive: true);
    if (!ok || !mounted) return;
    try { await ref.read(repositoryProvider).deleteFoodConsumption(meal['id'] as String); await _load(); }
    catch (error) { if (mounted) showOrvaError(context, error); }
  }

  @override
  Widget build(BuildContext context) {
    final isToday = DateUtils.isSameDay(_date, DateTime.now());
    return Scaffold(
      floatingActionButton: _tab == 'today'
          ? FloatingActionButton.extended(onPressed: () => _logConsumption(), icon: const Icon(Icons.restaurant_outlined), label: const Text('Registrar consumo'))
          : _tab == 'plans'
              ? FloatingActionButton.extended(onPressed: () => _editPlan(), icon: const Icon(Icons.event_available_outlined), label: const Text('Planejar refeição'))
              : FloatingActionButton.extended(onPressed: () => _editFood(), icon: const Icon(Icons.add), label: const Text('Novo alimento')),
      body: SafeArea(child: Column(children: [
        const OrvaPageHeader(title: 'Alimentação e saúde', subtitle: 'Planejamento e consumo são registros diferentes. Valores desconhecidos não são inventados.'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: OrvaSurface(child: Row(children: [
            IconButton(tooltip: 'Dia anterior', onPressed: () => _changeDate(-1), icon: const Icon(Icons.chevron_left)),
            Expanded(child: TextButton.icon(
              onPressed: _pickDate,
              icon: const Icon(Icons.calendar_today_outlined),
              label: Text(isToday ? 'Hoje · ${DateFormat('dd/MM/yyyy','pt_BR').format(_date)}' : DateFormat('EEEE, dd/MM/yyyy','pt_BR').format(_date), textAlign: TextAlign.center),
            )),
            IconButton(tooltip: 'Próximo dia', onPressed: () => _changeDate(1), icon: const Icon(Icons.chevron_right)),
          ])),
        ),
        const SizedBox(height: 10),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'today', label: Text('Consumo')),
              ButtonSegment(value: 'plans', label: Text('Planejamento')),
              ButtonSegment(value: 'foods', label: Text('Alimentos')),
            ],
            selected: {_tab},
            showSelectedIcon: false,
            onSelectionChanged: (values) => setState(() => _tab = values.first),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(child: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(onRefresh: _load, child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 104),
            children: [
              if (_tab == 'today') ...[
                _NutritionSummary(summary: _summary),
                const SizedBox(height: 18),
                Row(children: [
                  Expanded(child: Text('Refeições planejadas para este dia', style: Theme.of(context).textTheme.titleMedium)),
                  TextButton(onPressed: () => setState(() => _tab = 'plans'), child: const Text('Ver planos')),
                ]),
                if (_todayPlans.isEmpty)
                  const OrvaEmptyState(icon: Icons.event_note_outlined, title: 'Sem refeições planejadas', message: 'Você pode criar uma refeição para esta data ou definir uma recorrência.', compact: true)
                else
                  ..._todayPlans.map((p) => _planCard(p, today: true)),
                const SizedBox(height: 16),
                Text('O que você consumiu', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                if (_consumptions.isEmpty)
                  const OrvaEmptyState(icon: Icons.restaurant_outlined, title: 'Nenhum consumo registrado', message: 'Adicione o que realmente comeu. Isso não altera o planejamento.', compact: true)
                else
                  ..._consumptions.map((m) => _consumptionCard(m)),
              ],
              if (_tab == 'plans') ...[
                Text('Refeições e regras planejadas', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 6),
                Text('As recorrências são aplicadas ao consultar cada data. Planejar uma refeição não cria consumo.', style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 12),
                if (_allPlans.isEmpty)
                  const OrvaEmptyState(icon: Icons.event_available_outlined, title: 'Nenhum plano alimentar', message: 'Crie uma refeição pontual ou configure dias recorrentes.', compact: true, actionLabel: 'Planejar refeição', onAction: null)
                else
                  ..._allPlans.map((p) => _planCard(p, today: false)),
              ],
              if (_tab == 'foods') ...[
                Text('Catálogo de alimentos', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 6),
                Text('Cadastre informações de rótulos ou tabelas confiáveis; campos em branco permanecem desconhecidos.', style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 12),
                if (_foods.isEmpty)
                  OrvaEmptyState(icon: Icons.egg_alt_outlined, title: 'Seu catálogo está vazio', message: 'Adicione alimentos e informe apenas os valores nutricionais que você conhece.', actionLabel: 'Cadastrar alimento', onAction: () => _editFood(), compact: true)
                else
                  ..._foods.map(_foodCard),
              ],
            ],
          )),
        ),
      ])),
    );
  }

  Widget _planCard(Map<String,Object?> plan, {required bool today}) {
    final recurrence = switch(plan['recurrence']) {
      'daily' => 'Todos os dias',
      'weekly' => 'Dias da semana',
      'custom' => 'Personalizada',
      _ => 'Uma data',
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: OrvaSurface(padding: EdgeInsets.zero, child: ExpansionTile(
        leading: const Icon(Icons.event_note_outlined, color: OrvaColors.primary),
        title: Text('${plan['title']}', style: Theme.of(context).textTheme.titleSmall),
        subtitle: Text('${_mealTypes[plan['meal_type']] ?? 'Personalizada'} · ${plan['planned_minute'] == null ? 'sem horário' : formatClock(intValue(plan['planned_minute']))} · $recurrence'),
        childrenPadding: const EdgeInsets.fromLTRB(16,0,16,14),
        children: [
          if ((plan['note'] as String?)?.isNotEmpty == true) Align(alignment: Alignment.centerLeft, child: Text(plan['note'] as String)),
          FutureBuilder<List<Map<String,Object?>>>(
            future: ref.read(repositoryProvider).getMealPlanItems(plan['id'] as String),
            builder: (context,snapshot) {
              final items=snapshot.data??const <Map<String,Object?>>[];
              if(items.isEmpty) return const ListTile(dense:true,title:Text('Nenhum alimento vinculado ao plano'));
              return Column(children:items.map((item)=>ListTile(
                dense:true,
                title:Text('${item['food_name_snapshot']}'),
                subtitle:Text('${item['quantity']} ${item['unit']} · ${item['calories'] == null ? 'calorias não cadastradas' : '${(item['calories'] as num).round()} kcal estimadas pelo rótulo informado'}'),
                trailing:IconButton(tooltip:'Remover do plano',icon:const Icon(Icons.close),onPressed:()async{
                  await ref.read(repositoryProvider).deleteMealPlanItem(item['id'] as String); if(mounted) setState((){});
                }),
              )).toList());
            },
          ),
          Wrap(spacing:8,runSpacing:4,children:[
            OutlinedButton.icon(onPressed:()=>_addPlanItem(plan),icon:const Icon(Icons.add, size:18),label:const Text('Alimento')),
            if(today) FilledButton.icon(onPressed:()=>_logConsumption(plan),icon:const Icon(Icons.restaurant, size:18),label:const Text('Registrar consumo')),
            TextButton.icon(onPressed:()=>_editPlan(plan),icon:const Icon(Icons.edit_outlined,size:18),label:const Text('Editar')),
            TextButton.icon(onPressed:()=>_deletePlan(plan),icon:const Icon(Icons.delete_outline,size:18),label:const Text('Excluir')),
          ]),
        ],
      )),
    );
  }

  Widget _foodCard(Map<String,Object?> food) {
    String value(String key,String suffix) {
      final raw=food[key];
      return raw is num?' ${raw.toStringAsFixed(raw % 1 == 0 ? 0 : 1)}$suffix':'—';
    }
    return Padding(
      padding: const EdgeInsets.only(bottom:8),
      child: OrvaSurface(child:Row(children:[
        Container(width:42,height:42,decoration:BoxDecoration(color:OrvaColors.success.withValues(alpha:0.12),borderRadius:BorderRadius.circular(12)),child:const Icon(Icons.egg_alt_outlined,color:OrvaColors.success)),
        const SizedBox(width:10),
        Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          Text('${food['name']}',style:Theme.of(context).textTheme.titleSmall),
          if((food['brand'] as String?)?.isNotEmpty==true) Text(food['brand'] as String,style:Theme.of(context).textTheme.bodySmall),
          Text('Por ${food['reference_amount']} ${food['reference_unit']} · ${value('calories',' kcal')} · P ${value('protein_g','g')} · C ${value('carbohydrates_g','g')} · G ${value('fat_g','g')}',style:Theme.of(context).textTheme.bodySmall),
          Text('Origem: ${food['nutrition_source']}',style:Theme.of(context).textTheme.bodySmall),
        ])),
        PopupMenuButton<String>(onSelected:(choice){
          if(choice=='edit')_editFood(food);
          if(choice=='delete')_deleteFood(food);
        },itemBuilder:(_)=>const[
          PopupMenuItem(value:'edit',child:Text('Editar')),
          PopupMenuItem(value:'delete',child:Text('Excluir')),
        ]),
      ])),
    );
  }

  Widget _consumptionCard(Map<String,Object?> meal) => Padding(
    padding: const EdgeInsets.only(bottom:8),
    child:OrvaSurface(padding:EdgeInsets.zero,child:ExpansionTile(
      leading:const Icon(Icons.restaurant_outlined,color:OrvaColors.terracotta),
      title:Text('${meal['title']}',style:Theme.of(context).textTheme.titleSmall),
      subtitle:Text('${_mealTypes[meal['meal_type']]??'Personalizada'} · ${meal['consumed_minute']==null?'horário não informado':formatClock(intValue(meal['consumed_minute']))} · ${intValue(meal['item_count'])} alimento(s)'),
      childrenPadding:const EdgeInsets.fromLTRB(16,0,16,12),
      children:[
        FutureBuilder<List<Map<String,Object?>>>(
          future:ref.read(repositoryProvider).getFoodConsumptionItems(meal['id'] as String),
          builder:(context,snapshot){
            final items=snapshot.data??const <Map<String,Object?>>[];
            if(items.isEmpty)return const ListTile(dense:true,title:Text('Nenhum alimento detalhado foi vinculado a este registro.'));
            return Column(children:items.map((item)=>ListTile(
              dense:true,
              title:Text('${item['food_name_snapshot']}'),
              subtitle:Text('${item['quantity']} ${item['unit']} · ${item['calories']==null?'kcal desconhecidas':'${(item['calories'] as num).toStringAsFixed(1)} kcal (estimativa dos dados informados)'}'),
            )).toList());
          },
        ),
        if((meal['note'] as String?)?.isNotEmpty==true) Align(alignment:Alignment.centerLeft,child:Text(meal['note'] as String)),
        Align(alignment:Alignment.centerRight,child:TextButton.icon(onPressed:()=>_deleteConsumption(meal),icon:const Icon(Icons.delete_outline,size:18),label:const Text('Excluir registro'))),
      ],
    )),
  );
}

class _NutritionSummary extends StatelessWidget {
  const _NutritionSummary({required this.summary});
  final Map<String,Object?> summary;

  @override
  Widget build(BuildContext context) {
    final items=intValue(summary['itemCount']);
    final kcal=summary['calories'];
    final partial=summary['isPartial']==true;
    String nutrient(String key,String suffix) {
      final raw=summary[key];
      if(raw is! num) return 'Sem dados';
      return '${raw.toStringAsFixed(raw % 1 == 0 ? 0 : 1)}$suffix';
    }
    return OrvaSurface(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Row(children:[
        Expanded(child:Text('Resumo do consumo',style:Theme.of(context).textTheme.titleMedium)),
        if(partial)const Chip(label:Text('Parcial'),avatar:Icon(Icons.info_outline,size:16)),
      ]),
      const SizedBox(height:4),
      Text('${intValue(summary['consumptionCount'])} refeição(ões) · $items alimento(s) registrados',style:Theme.of(context).textTheme.bodySmall),
      const SizedBox(height:16),
      Row(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          Text(kcal is num?'${kcal.toStringAsFixed(kcal % 1 == 0 ? 0 : 1)}':'—',style:Theme.of(context).textTheme.headlineMedium?.copyWith(color:OrvaColors.primary)),
          Text('kcal conhecidas',style:Theme.of(context).textTheme.bodySmall),
        ])),
        Expanded(child:_SmallNutrient(label:'Proteína',value:nutrient('protein_g',' g'))),
        Expanded(child:_SmallNutrient(label:'Carboidrato',value:nutrient('carbohydrates_g',' g'))),
        Expanded(child:_SmallNutrient(label:'Gordura',value:nutrient('fat_g',' g'))),
      ]),
      if(items==0) ...[
        const SizedBox(height:10),
        Text('Os totais aparecem após registrar alimentos com valores nutricionais conhecidos.',style:Theme.of(context).textTheme.bodySmall),
      ] else if(partial) ...[
        const SizedBox(height:10),
        Text('Os totais mostram somente valores conhecidos; alguns alimentos não têm todos os dados. Não é um total nutricional completo.',style:Theme.of(context).textTheme.bodySmall),
      ],
    ]));
  }
}

class _SmallNutrient extends StatelessWidget {
  const _SmallNutrient({required this.label,required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context)=>Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
    Text(value,style:Theme.of(context).textTheme.titleSmall),
    Text(label,style:Theme.of(context).textTheme.bodySmall),
  ]);
}

class _FoodConsumptionDialog extends StatefulWidget {
  const _FoodConsumptionDialog({
    required this.repository,
    required this.foods,
    required this.date,
    this.plannedMeal,
    this.suggestedItems = const [],
  });
  final OrvaRepository repository;
  final List<Map<String,Object?>> foods;
  final DateTime date;
  final Map<String,Object?>? plannedMeal;
  final List<FoodQuantity> suggestedItems;
  @override
  State<_FoodConsumptionDialog> createState()=>_FoodConsumptionDialogState();
}

class _FoodConsumptionDialogState extends State<_FoodConsumptionDialog> {
  late final TextEditingController _title=TextEditingController(text:widget.plannedMeal?['title'] as String? ?? '');
  late final TextEditingController _note=TextEditingController();
  late final TextEditingController _quantity=TextEditingController(text:'100');
  String _mealType='custom';
  String _foodId='';
  late DateTime _date=DateTime(widget.date.year,widget.date.month,widget.date.day);
  int? _minute;
  final List<FoodQuantity> _items=[];
  bool _saving=false;

  @override
  void initState(){
    super.initState();
    _mealType=widget.plannedMeal?['meal_type'] as String? ?? 'custom';
    _items.addAll(widget.suggestedItems);
    if(widget.foods.isNotEmpty){_foodId=widget.foods.first['id'] as String;_quantity.text='${widget.foods.first['reference_amount']}';}
    final now=DateTime.now();
    _minute=DateUtils.isSameDay(_date,now)?now.hour*60+now.minute:null;
  }

  @override
  void dispose(){_title.dispose();_note.dispose();_quantity.dispose();super.dispose();}

  Map<String,Object?>? get _selectedFood {
    for(final food in widget.foods){if(food['id']==_foodId)return food;}
    return null;
  }

  void _addFood(){
    final food=_selectedFood;
    final quantity=_parseNullableDouble(_quantity.text);
    if(food==null){showOrvaMessage(context,'Cadastre e selecione um alimento.');return;}
    if(quantity==null||quantity<=0){showOrvaMessage(context,'Informe uma quantidade positiva.');return;}
    setState(()=>_items.add(FoodQuantity(foodId:_foodId,quantity:quantity)));
  }

  Future<void> _save() async{
    if(_title.text.trim().isEmpty){showOrvaMessage(context,'Informe o nome da refeição.');return;}
    setState(()=>_saving=true);
    try{
      await widget.repository.saveFoodConsumption(
        consumedDate:_date,
        consumedMinute:_minute,
        mealType:_mealType,
        title:_title.text,
        note:_note.text,
        items:_items,
      );
      if(mounted)Navigator.pop(context,true);
    }catch(error){
      if(mounted){setState(()=>_saving=false);showOrvaMessage(context,'Não foi possível salvar o consumo. Revise os alimentos e quantidades.');}
    }
  }

  @override
  Widget build(BuildContext context)=>AlertDialog(
    title:const Text('Registrar o que consumiu'),
    content:SizedBox(
      width:480,
      child:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[
        TextField(controller:_title,autofocus:true,maxLength:120,decoration:const InputDecoration(labelText:'Nome da refeição *')),
        const SizedBox(height:8),
        DropdownButtonFormField<String>(
          value:_mealType,
          decoration:const InputDecoration(labelText:'Tipo'),
          items:_mealTypes.entries.map((e)=>DropdownMenuItem(value:e.key,child:Text(e.value))).toList(),
          onChanged:(v)=>setState(()=>_mealType=v??'custom'),
        ),
        OutlinedButton.icon(
          onPressed:()async{
            final d=await showDatePicker(context:context,initialDate:_date,firstDate:DateTime(2000),lastDate:DateTime(2100));
            if(d!=null)setState(()=>_date=d);
          },
          icon:const Icon(Icons.calendar_today_outlined),
          label:Text('Data: ${DateFormat('dd/MM/yyyy','pt_BR').format(_date)}'),
        ),
        OutlinedButton.icon(
          onPressed:()async{
            final initial=_minute==null?TimeOfDay.now():TimeOfDay(hour:_minute!~/60,minute:_minute!%60);
            final t=await showTimePicker(context:context,initialTime:initial);
            if(t!=null)setState(()=>_minute=t.hour*60+t.minute);
          },
          icon:const Icon(Icons.schedule_outlined),
          label:Text(_minute==null?'Adicionar horário':'Horário: ${formatClock(_minute!)}'),
        ),
        const Divider(height:20),
        if (widget.suggestedItems.isNotEmpty) ...[
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Itens sugeridos do planejamento. Confira e ajuste para refletir o que realmente consumiu.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          const SizedBox(height: 8),
        ],
        Align(alignment:Alignment.centerLeft,child:Text('Alimentos da refeição',style:Theme.of(context).textTheme.titleSmall)),
        const SizedBox(height:6),
        if(widget.foods.isEmpty)
          const Align(alignment:Alignment.centerLeft,child:Text('O catálogo está vazio. Você ainda pode registrar a refeição por nome e observações.'))
        else ...[
          DropdownButtonFormField<String>(
            value:_foodId,
            isExpanded:true,
            decoration:const InputDecoration(labelText:'Alimento cadastrado'),
            items:widget.foods.map((f)=>DropdownMenuItem(value:f['id'] as String,child:Text('${f['name']} · por ${f['reference_amount']} ${f['reference_unit']}',overflow:TextOverflow.ellipsis))).toList(),
            onChanged:(v){
              setState(() {
                _foodId = v ?? _foodId;
                final food = _selectedFood;
                if (food != null) _quantity.text = '${food['reference_amount']}';
              });
            },
          ),
          const SizedBox(height:8),
          Row(children:[
            Expanded(child:TextField(controller:_quantity,keyboardType:const TextInputType.numberWithOptions(decimal:true),decoration:InputDecoration(labelText:'Quantidade (${_selectedFood?['reference_unit']??''})'))),
            const SizedBox(width:8),
            FilledButton.tonal(onPressed:_addFood,child:const Text('Adicionar')),
          ]),
          ..._items.asMap().entries.map((entry){
            Map<String,Object?>? food;
            for (final candidate in widget.foods) {
              if (candidate['id'] == entry.value.foodId) { food = candidate; break; }
            }
            return ListTile(
              dense:true,
              contentPadding:EdgeInsets.zero,
              title:Text(food?['name'] as String? ?? 'Alimento removido'),
              subtitle:Text('${entry.value.quantity} ${food?['reference_unit']??''}'),
              trailing:IconButton(tooltip:'Remover item',onPressed:()=>setState(() { _items.removeAt(entry.key); }),icon:const Icon(Icons.close)),
            );
          }),
        ],
        const SizedBox(height:8),
        TextField(controller:_note,maxLines:2,decoration:const InputDecoration(labelText:'Observações opcionais')),
      ])),
    ),
    actions:[
      TextButton(onPressed:_saving?null:()=>Navigator.pop(context,false),child:const Text('Cancelar')),
      FilledButton(onPressed:_saving?null:_save,child:_saving?const SizedBox(width:18,height:18,child:CircularProgressIndicator(strokeWidth:2)):const Text('Salvar consumo')),
    ],
  );
}

String _dateKey(DateTime date)=>'${date.year.toString().padLeft(4,'0')}-${date.month.toString().padLeft(2,'0')}-${date.day.toString().padLeft(2,'0')}';
