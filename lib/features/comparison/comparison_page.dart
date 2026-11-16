import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/comparison_repository.dart';
import '../../core/database/orva_repository.dart';
import '../../core/domain/comparison_scoring.dart';
import '../../core/theme/orva_theme.dart';
import '../../core/widgets/orva_widgets.dart';

/// Beto vs Alfredo: two fixed identities compared over user-defined, measurable
/// traits. The screen only reports criteria with evidence; missing data is shown
/// as unknown and never assigned to a side.
class ComparisonPage extends ConsumerStatefulWidget {
  const ComparisonPage({super.key});

  @override
  ConsumerState<ComparisonPage> createState() => _ComparisonPageState();
}

class _ComparisonPageState extends ConsumerState<ComparisonPage> {
  bool _loading = true;
  ComparisonPeriod _period = ComparisonPeriod.last30Days;
  Map<String, Map<String, Object?>> _profiles = const {};
  List<_TraitView> _traits = const [];
  List<Map<String, Object?>> _habitSources = const [];
  List<Map<String, Object?>> _studySources = const [];
  ComparisonSummary _summary = const ComparisonSummary.empty();
  DateTime _loadedAt = DateTime.now();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final repo = ref.read(repositoryProvider);
      await repo.ensureComparisonSeeded();
      final period = await repo.getComparisonPeriod();
      final profiles = await repo.getComparisonProfiles();
      final traits = await repo.getComparisonTraits();
      final habitSources = await repo.getComparisonSources(
        TraitMeasurement.habitQuantity,
      );
      final studySources = await repo.getComparisonSources(
        TraitMeasurement.studyMinutes,
      );
      final now = DateTime.now();
      final views = <_TraitView>[];
      for (final trait in traits) {
        final rule = _ruleOf(trait);
        final window = resolveComparisonWindow(
          traitWindowDays: rule.windowDays,
          selected: period,
          today: now,
        );
        final measured = await repo.measureComparisonTrait(trait, window);
        views.add(
          _TraitView(
            trait: trait,
            evaluation: evaluateTrait(
              traitId: trait['id'] as String,
              rule: rule,
              measuredValue: measured,
              window: window,
            ),
            checkedToday: rule.measurement == TraitMeasurement.manualCheckin
                ? await repo.isComparisonCheckedIn(trait['id'] as String, now)
                : false,
          ),
        );
      }
      final summary = summarizeComparison(
        views.where((view) => view.active).map((view) => view.evaluation),
      );
      if (!mounted) return;
      setState(() {
        _period = period;
        _profiles = profiles;
        _traits = views;
        _habitSources = habitSources;
        _studySources = studySources;
        _summary = summary;
        _loadedAt = now;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _loading = false);
      showOrvaError(context, error);
    }
  }

  TraitRule _ruleOf(Map<String, Object?> trait) => TraitRule(
    side: comparisonSideFromStorage(trait['target_character'] as String),
    measurement: traitMeasurementFromStorage(
      trait['measurement_type'] as String,
    ),
    threshold: (trait['threshold'] as num).toDouble(),
    weight: (trait['weight'] as num?)?.toDouble() ?? 1,
    windowDays: (trait['window_days'] as num?)?.toInt() ?? 0,
  );

  String _displayName(ComparisonSide side) {
    final profile = _profiles[comparisonSideStorageValue(side)];
    final name = (profile?['display_name'] as String?)?.trim();
    return name == null || name.isEmpty
        ? (side == ComparisonSide.alfredo ? 'Alfredo' : 'Beto')
        : name;
  }

  Future<void> _selectPeriod(ComparisonPeriod period) async {
    if (period == _period) return;
    try {
      await ref.read(repositoryProvider).setComparisonPeriod(period);
      await _load();
    } catch (error) {
      if (mounted) showOrvaError(context, error);
    }
  }

  Future<void> _toggleToday(_TraitView view) async {
    try {
      await ref
          .read(repositoryProvider)
          .toggleComparisonCheckin(
            traitId: view.trait['id'] as String,
            date: DateTime.now(),
          );
      await _load();
    } catch (error) {
      if (mounted) showOrvaError(context, error);
    }
  }

  Future<void> _toggleActive(_TraitView view, bool active) async {
    if (active && view.sensitive) {
      final confirmed = await confirmAction(
        context,
        title: 'Ativar critério sensível',
        message: 'Este critério descreve um comportamento que você quer reduzir. Ele é opcional, fica apenas neste aparelho e não é usado para diagnóstico. Ativar?',
        actionLabel: 'Ativar',
      );
      if (!confirmed) return;
    }
    try {
      await ref
          .read(repositoryProvider)
          .setComparisonTraitActive(view.trait['id'] as String, active);
      await _load();
    } catch (error) {
      if (mounted) showOrvaError(context, error);
    }
  }

  Future<void> _deleteTrait(_TraitView view) async {
    final confirmed = await confirmAction(
      context,
      title: 'Excluir critério',
      message:
          'O critério "${view.label}" e os registros de check-in dele serão removidos de vez. Registros de hábitos e estudos não são afetados.',
      actionLabel: 'Excluir',
      destructive: true,
    );
    if (!confirmed) return;
    try {
      await ref
          .read(repositoryProvider)
          .deleteComparisonTrait(view.trait['id'] as String);
      await _load();
    } catch (error) {
      if (mounted) showOrvaError(context, error);
    }
  }

  Future<void> _editProfiles() async {
    final alfredoName = TextEditingController(
      text: _displayName(ComparisonSide.alfredo),
    );
    final alfredoDescription = TextEditingController(
      text: _profiles['alfredo']?['description'] as String? ?? '',
    );
    final betoName = TextEditingController(
      text: _displayName(ComparisonSide.beto),
    );
    final betoDescription = TextEditingController(
      text: _profiles['beto']?['description'] as String? ?? '',
    );
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Personalizar personagens'),
        content: SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'A dupla é fixa: Beto e Alfredo. Você pode mudar como eles aparecem e o que representam.',
                  style: Theme.of(dialog).textTheme.bodySmall,
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: alfredoName,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Nome do lado que você quer fortalecer',
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: alfredoDescription,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Descrição (opcional)',
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: betoName,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Nome do lado que você quer reduzir',
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: betoDescription,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Descrição (opcional)',
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialog, true),
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
    try {
      if (saved == true) {
        final repo = ref.read(repositoryProvider);
        await repo.saveComparisonProfile(
          side: ComparisonSide.alfredo,
          displayName: alfredoName.text,
          description: alfredoDescription.text,
        );
        await repo.saveComparisonProfile(
          side: ComparisonSide.beto,
          displayName: betoName.text,
          description: betoDescription.text,
        );
        await _load();
      }
    } catch (error) {
      if (mounted) showOrvaError(context, error);
    } finally {
      alfredoName.dispose();
      alfredoDescription.dispose();
      betoName.dispose();
      betoDescription.dispose();
    }
  }

  Future<void> _editTrait([_TraitView? view]) async {
    final trait = view?.trait;
    final label = TextEditingController(text: trait?['label'] as String? ?? '');
    final explanation = TextEditingController(
      text: trait?['explanation'] as String? ?? '',
    );
    final threshold = TextEditingController(
      text: trait?['threshold']?.toString() ?? '',
    );
    final unit = TextEditingController(
      text: trait?['unit'] as String? ?? 'dias',
    );
    final weight = TextEditingController(
      text: trait?['weight']?.toString() ?? '1',
    );
    final windowDays = TextEditingController(
      text: trait?['window_days']?.toString() ?? '0',
    );

    var side = trait == null
        ? ComparisonSide.alfredo
        : comparisonSideFromStorage(trait['target_character'] as String);
    var measurement = trait == null
        ? TraitMeasurement.manualCheckin
        : traitMeasurementFromStorage(trait['measurement_type'] as String);
    var sourceId = trait?['source_id'] as String?;
    var sensitive = (trait?['is_sensitive'] as int? ?? 0) == 1;
    var active = (trait?['is_active'] as int? ?? 1) == 1;
    String? error;

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialog) => StatefulBuilder(
        builder: (dialog, setDialogState) {
          final sources = switch (measurement) {
            TraitMeasurement.manualCheckin => const <Map<String, Object?>>[],
            TraitMeasurement.habitQuantity => _habitSources,
            TraitMeasurement.studyMinutes => _studySources,
          };
          final sourceMissing =
              measurement != TraitMeasurement.manualCheckin &&
              sources.isNotEmpty &&
              !sources.any((row) => row['id'] == sourceId);
          return AlertDialog(
            title: Text(trait == null ? 'Novo critério' : 'Editar critério'),
            content: SizedBox(
              width: 440,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: label,
                      autofocus: trait == null,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                        labelText: 'Critério *',
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: explanation,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'O que ele mede',
                        hintText: 'Ex.: dias com treino registrado',
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Quem se fortalece ao atingir a meta',
                      style: Theme.of(dialog).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 6),
                    SegmentedButton<ComparisonSide>(
                      segments: [
                        ButtonSegment(
                          value: ComparisonSide.alfredo,
                          label: Text(_displayName(ComparisonSide.alfredo)),
                        ),
                        ButtonSegment(
                          value: ComparisonSide.beto,
                          label: Text(_displayName(ComparisonSide.beto)),
                        ),
                      ],
                      selected: {side},
                      onSelectionChanged: (value) =>
                          setDialogState(() => side = value.first),
                    ),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<TraitMeasurement>(
                      initialValue: measurement,
                      decoration: const InputDecoration(
                        labelText: 'Como a evidência é obtida',
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: TraitMeasurement.manualCheckin,
                          child: Text('Check-in manual'),
                        ),
                        DropdownMenuItem(
                          value: TraitMeasurement.habitQuantity,
                          child: Text('Quantidade de um hábito'),
                        ),
                        DropdownMenuItem(
                          value: TraitMeasurement.studyMinutes,
                          child: Text('Minutos de estudo'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value == null) return;
                        setDialogState(() {
                          measurement = value;
                          sourceId = null;
                          if (value == TraitMeasurement.studyMinutes) {
                            unit.text = 'min';
                          } else if (value == TraitMeasurement.manualCheckin) {
                            unit.text = 'dias';
                          }
                        });
                      },
                    ),
                    if (sources.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        initialValue: sourceMissing ? null : sourceId,
                        decoration: const InputDecoration(
                          labelText: 'Origem dos registros',
                        ),
                        items: [
                          for (final row in sources)
                            DropdownMenuItem(
                              value: row['id'] as String,
                              child: Text(row['name'] as String),
                            ),
                        ],
                        onChanged: (value) =>
                            setDialogState(() => sourceId = value),
                      ),
                    ] else if (measurement !=
                        TraitMeasurement.manualCheckin) ...[
                      const SizedBox(height: 8),
                      Text(
                        measurement == TraitMeasurement.habitQuantity
                            ? 'Nenhum hábito ativo. Crie um em Hábitos para usar esta evidência.'
                            : 'Nenhuma matéria ativa. Crie uma em Estudos para usar esta evidência.',
                        style: Theme.of(dialog).textTheme.bodySmall,
                      ),
                    ],
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: threshold,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: const InputDecoration(
                              labelText: 'Meta mínima *',
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: unit,
                            decoration: const InputDecoration(
                              labelText: 'Unidade',
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: weight,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: const InputDecoration(
                              labelText: 'Peso',
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: windowDays,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Janela (dias)',
                              helperText: '0 = seguir o período',
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      value: sensitive,
                      onChanged: (value) =>
                          setDialogState(() => sensitive = value),
                      title: const Text('Critério sensível'),
                      subtitle: const Text(
                        'Fica desativado até você mesmo ativá-lo. Nunca vira diagnóstico.',
                      ),
                    ),
                    if (!sensitive)
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        value: active,
                        onChanged: (value) =>
                            setDialogState(() => active = value),
                        title: const Text('Ativo na comparação'),
                      ),
                    if (error != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        error!,
                        style: const TextStyle(color: OrvaColors.error),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialog, false),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: () {
                  final parsedThreshold = double.tryParse(
                    threshold.text.trim().replaceAll(',', '.'),
                  );
                  if (label.text.trim().isEmpty) {
                    setDialogState(() => error = 'Informe o nome do critério.');
                    return;
                  }
                  if (parsedThreshold == null || parsedThreshold <= 0) {
                    setDialogState(
                      () => error = 'A meta deve ser um número maior que zero.',
                    );
                    return;
                  }
                  if (measurement != TraitMeasurement.manualCheckin &&
                      (sourceId == null || sourceId!.isEmpty)) {
                    setDialogState(
                      () => error = 'Selecione a origem dos registros.',
                    );
                    return;
                  }
                  Navigator.pop(dialog, true);
                },
                child: const Text('Salvar'),
              ),
            ],
          );
        },
      ),
    );

    try {
      if (saved == true) {
        await ref
            .read(repositoryProvider)
            .saveComparisonTrait(
              id: trait?['id'] as String?,
              label: label.text,
              explanation: explanation.text,
              side: side,
              measurement: measurement,
              sourceId: measurement == TraitMeasurement.manualCheckin
                  ? null
                  : sourceId,
              threshold: double.parse(
                threshold.text.trim().replaceAll(',', '.'),
              ),
              unit: unit.text,
              weight:
                  double.tryParse(weight.text.trim().replaceAll(',', '.')) ?? 1,
              windowDays: int.tryParse(windowDays.text.trim()) ?? 0,
              sensitive: sensitive,
              active: active,
            );
        await _load();
      }
    } catch (error) {
      if (mounted) showOrvaError(context, error);
    } finally {
      label.dispose();
      explanation.dispose();
      threshold.dispose();
      unit.dispose();
      weight.dispose();
      windowDays.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    final active = _traits.where((view) => view.active).toList();
    final inactive = _traits.where((view) => !view.active).toList();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Alter egos'),
        actions: [
          IconButton(
            tooltip: 'Personalizar personagens',
            onPressed: _loading ? null : _editProfiles,
            icon: const Icon(Icons.tune_rounded),
          ),
          IconButton(
            tooltip: 'Novo critério',
            onPressed: _loading ? null : () => _editTrait(),
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
                children: [
                  _ScoreCard(
                    alfredoName: _displayName(ComparisonSide.alfredo),
                    betoName: _displayName(ComparisonSide.beto),
                    alfredoDescription:
                        _profiles['alfredo']?['description'] as String? ?? '',
                    betoDescription:
                        _profiles['beto']?['description'] as String? ?? '',
                    summary: _summary,
                    period: _period,
                    periodRange: resolveComparisonWindow(
                      traitWindowDays: 0,
                      selected: _period,
                      today: _loadedAt,
                    ),
                    loadedAt: _loadedAt,
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final period in ComparisonPeriod.values)
                        ChoiceChip(
                          label: Text(_periodLabel(period)),
                          selected: _period == period,
                          onSelected: (_) => _selectPeriod(period),
                        ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  OrvaSectionHeader(
                    title: 'Critérios ativos',
                    actionLabel: 'Novo',
                    onAction: () => _editTrait(),
                  ),
                  const SizedBox(height: 8),
                  if (active.isEmpty)
                    OrvaEmptyState(
                      icon: Icons.balance_outlined,
                      title: 'Nenhum critério ativo',
                      message: 'Escolha comportamentos mensuráveis. Sem evidência, o resultado fica em aberto em vez de virar culpa.',
                      actionLabel: 'Criar critério',
                      onAction: () => _editTrait(),
                      compact: true,
                    )
                  else
                    for (final view in active) ...[
                      _TraitCard(
                        view: view,
                        title: view.label,
                        subtitle: _traitSubtitle(view),
                        evidence: _evidenceLabel(view),
                        outcomeSide: _outcomeSideName(view.evaluation),
                        outcomeLabel: _outcomeLabel(view.evaluation),
                        color: _outcomeColor(view.evaluation),
                        onToggleToday:
                            view.evaluation.measurement ==
                                TraitMeasurement.manualCheckin
                            ? () => _toggleToday(view)
                            : null,
                        onMenu: (action) {
                          switch (action) {
                            case _TraitAction.edit:
                              _editTrait(view);
                            case _TraitAction.toggle:
                              _toggleActive(view, false);
                            case _TraitAction.delete:
                              _deleteTrait(view);
                          }
                        },
                      ),
                      const SizedBox(height: 10),
                    ],
                  if (inactive.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    const OrvaSectionHeader(title: 'Desativados'),
                    const SizedBox(height: 4),
                    Text(
                      'Critérios sensíveis ficam desligados até você ativar. Eles nunca entram no cálculo enquanto estiverem assim.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 10),
                    for (final view in inactive)
                      OrvaSurface(
                        padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    view.label,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium,
                                  ),
                                  if ((view.trait['explanation'] as String?)
                                          ?.isNotEmpty ==
                                      true) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      view.trait['explanation'] as String,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall,
                                    ),
                                  ],
                                  if ((view.trait['is_sensitive'] as int? ??
                                          0) ==
                                      1) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      'Sensível · exige ativação explícita',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(color: OrvaColors.mustard),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            TextButton(
                              onPressed: () => _toggleActive(view, true),
                              child: const Text('Ativar'),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 10),
                  ],
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: _showMethodNote,
                    child: const OrvaSurface(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.info_outline_rounded,
                            color: OrvaColors.primary,
                            size: 20,
                          ),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'O percentual usa só os critérios com evidência no período. Sem registro não é ponto para nenhum lado — é dados insuficientes. Veja como o cálculo funciona.',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  String _traitSubtitle(_TraitView view) {
    final rule = view.evaluation;
    final parts = <String>[
      'meta ${_formatValue(rule.threshold)} ${view.unit}',
      '${view.evaluation.window.days} dias',
      'peso ${_formatValue(rule.weight)}',
    ];
    return parts.join(' · ');
  }

  String _evidenceLabel(_TraitView view) {
    final evaluation = view.evaluation;
    if (evaluation.measuredValue == null) {
      return switch (evaluation.measurement) {
        TraitMeasurement.manualCheckin => 'Nenhum check-in no período',
        TraitMeasurement.habitQuantity => 'Nenhum registro no hábito vinculado',
        TraitMeasurement.studyMinutes => 'Nenhuma sessão de estudo no período',
      };
    }
    final measured = '${_formatValue(evaluation.measuredValue!)} ${view.unit}';
    return switch (evaluation.measurement) {
      TraitMeasurement.manualCheckin => '$measured com check-in',
      TraitMeasurement.habitQuantity => '$measured no hábito vinculado',
      TraitMeasurement.studyMinutes => '$measured de estudo registrados',
    };
  }

  String? _outcomeSideName(TraitEvaluation evaluation) =>
      switch (evaluation.outcome) {
        TraitOutcome.favorsAlfredo => _displayName(ComparisonSide.alfredo),
        TraitOutcome.favorsBeto => _displayName(ComparisonSide.beto),
        TraitOutcome.neutral => 'Neutro',
        TraitOutcome.unknown => 'Sem dados',
      };

  String _outcomeLabel(TraitEvaluation evaluation) =>
      switch (evaluation.outcome) {
        TraitOutcome.favorsAlfredo ||
        TraitOutcome.favorsBeto => 'meta atingida',
        TraitOutcome.neutral => 'meta não atingida',
        TraitOutcome.unknown => 'não avaliado',
      };

  Color _outcomeColor(TraitEvaluation evaluation) =>
      switch (evaluation.outcome) {
        TraitOutcome.favorsAlfredo => OrvaColors.primary,
        TraitOutcome.favorsBeto => OrvaColors.terracotta,
        TraitOutcome.neutral => OrvaColors.mustard,
        TraitOutcome.unknown => OrvaColors.tertiaryText,
      };

  void _showMethodNote() {
    showDialog<void>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Como o resultado é calculado'),
        content: const SingleChildScrollView(
          child: Text(
            'Cada critério ativo tem uma meta, um peso e uma janela. O critério pesa para o seu personagem '
            'quando a evidência do período alcança a meta. Sem atingir a meta, fica neutro. Sem nenhum '
            'registro no período, fica desconhecido.\n\n'
            'Percentual de um lado = peso desse lado ÷ peso dos critérios avaliados.\n'
            'Cobertura = critérios avaliados ÷ critérios ativos.\n\n'
            'Neutros e desconhecidos não entram no denominador, então o resultado nunca é 50/50 por padrão. '
            'Critérios que leem hábitos ou sessões de estudo usam os registros que você já tinha, sem pedir '
            'para registrar de novo. Check-ins manuais são seus, ficam no aparelho e podem ser desmarcados.\n\n'
            'Isso descreve comportamentos escolhidos num período — não a sua identidade, saúde ou caráter.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog),
            child: const Text('Entendi'),
          ),
        ],
      ),
    );
  }
}

enum _TraitAction { edit, toggle, delete }

class _TraitView {
  const _TraitView({
    required this.trait,
    required this.evaluation,
    required this.checkedToday,
  });

  final Map<String, Object?> trait;
  final TraitEvaluation evaluation;
  final bool checkedToday;

  bool get active => (trait['is_active'] as int? ?? 1) == 1;
  bool get sensitive => (trait['is_sensitive'] as int? ?? 0) == 1;
  String get label => trait['label'] as String;
  String get unit => (trait['unit'] as String?) ?? '';
}

class _ScoreCard extends StatelessWidget {
  const _ScoreCard({
    required this.alfredoName,
    required this.betoName,
    required this.alfredoDescription,
    required this.betoDescription,
    required this.summary,
    required this.period,
    required this.periodRange,
    required this.loadedAt,
  });

  final String alfredoName;
  final String betoName;
  final String alfredoDescription;
  final String betoDescription;
  final ComparisonSummary summary;
  final ComparisonPeriod period;
  final DateRange periodRange;
  final DateTime loadedAt;

  @override
  Widget build(BuildContext context) {
    final alfredoShare = summary.alfredoShare;
    final betoShare = summary.betoShare;
    final coverage = (summary.coverage * 100).round();
    final alfredoFlex = (summary.alfredoWeight * 1000).round();
    final betoFlex = (summary.betoWeight * 1000).round();
    return OrvaSurface(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Quem está em vantagem',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      summary.hasEvidence
                          ? '${_percent(alfredoShare!)} $alfredoName'
                          : 'Dados insuficientes',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: OrvaColors.primary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  'cobertura $coverage%',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: OrvaColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _SideBlock(
                  name: alfredoName,
                  description: alfredoDescription,
                  share: alfredoShare,
                  color: OrvaColors.primary,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text('vs', style: Theme.of(context).textTheme.bodySmall),
              ),
              Expanded(
                child: _SideBlock(
                  name: betoName,
                  description: betoDescription,
                  share: betoShare,
                  color: OrvaColors.terracotta,
                  alignEnd: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: SizedBox(
              height: 8,
              child: summary.hasEvidence
                  ? Row(
                      children: [
                        if (alfredoFlex > 0)
                          Expanded(
                            flex: alfredoFlex,
                            child: const ColoredBox(color: OrvaColors.primary),
                          ),
                        if (betoFlex > 0)
                          Expanded(
                            flex: betoFlex,
                            child: const ColoredBox(
                              color: OrvaColors.terracotta,
                            ),
                          ),
                      ],
                    )
                  : const ColoredBox(color: OrvaColors.subtle),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            summary.hasEvidence
                ? '${summary.assessedTraits} de ${summary.activeTraits} critérios ativos têm evidência no período. '
                      '${summary.neutralTraits} ficaram neutros e ${summary.unknownTraits} sem dados.'
                : summary.activeTraits == 0
                ? 'Nenhum critério ativo ainda. Crie pelo menos um para começar.'
                : 'Nenhum critério ativo tem evidência neste período. O resultado fica em aberto.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 6),
          Text(
            'Período: ${_periodLabel(period)} (${_rangeLabel(periodRange)}) · atualizado ${_clockLabel(loadedAt)}',
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: OrvaColors.tertiaryText),
          ),
        ],
      ),
    );
  }
}

class _SideBlock extends StatelessWidget {
  const _SideBlock({
    required this.name,
    required this.description,
    required this.share,
    required this.color,
    this.alignEnd = false,
  });

  final String name;
  final String description;
  final double? share;
  final Color color;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: alignEnd
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        Text(
          name,
          textAlign: alignEnd ? TextAlign.end : TextAlign.start,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.titleMedium
              ?.copyWith(color: color),
        ),
        const SizedBox(height: 2),
        Text(
          share == null ? 'sem dados' : _percent(share!),
          style: orvaMonoStyle(
            fontSize: 26,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
        if (description.trim().isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(
            description,
            textAlign: alignEnd ? TextAlign.end : TextAlign.start,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ],
    );
  }
}

class _TraitCard extends StatelessWidget {
  const _TraitCard({
    required this.view,
    required this.title,
    required this.subtitle,
    required this.evidence,
    required this.outcomeSide,
    required this.outcomeLabel,
    required this.color,
    required this.onToggleToday,
    required this.onMenu,
  });

  final _TraitView view;
  final String title;
  final String subtitle;
  final String evidence;
  final String? outcomeSide;
  final String outcomeLabel;
  final Color color;
  final VoidCallback? onToggleToday;
  final void Function(_TraitAction action) onMenu;

  @override
  Widget build(BuildContext context) {
    return OrvaSurface(
      padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              PopupMenuButton<_TraitAction>(
                tooltip: 'Opções do critério',
                onSelected: onMenu,
                itemBuilder: (context) => const [
                  PopupMenuItem(
                    value: _TraitAction.edit,
                    child: Text('Editar'),
                  ),
                  PopupMenuItem(
                    value: _TraitAction.toggle,
                    child: Text('Desativar'),
                  ),
                  PopupMenuItem(
                    value: _TraitAction.delete,
                    child: Text('Excluir'),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  outcomeSide ?? outcomeLabel,
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: color, fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  evidence,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              if (onToggleToday != null)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: TextButton.icon(
                    onPressed: onToggleToday,
                    icon: Icon(
                      view.checkedToday
                          ? Icons.check_circle
                          : Icons.radio_button_unchecked,
                      size: 18,
                      color: view.checkedToday
                          ? OrvaColors.primary
                          : OrvaColors.tertiaryText,
                    ),
                    label: Text(view.checkedToday ? 'Hoje' : 'Marcar'),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

String _periodLabel(ComparisonPeriod period) => switch (period) {
  ComparisonPeriod.last7Days => 'Últimos 7 dias',
  ComparisonPeriod.last30Days => 'Últimos 30 dias',
  ComparisonPeriod.currentWeek => 'Semana atual',
  ComparisonPeriod.currentMonth => 'Mês atual',
};

String _two(int value) => value.toString().padLeft(2, '0');

String _rangeLabel(DateRange range) =>
    '${_two(range.start.day)}/${_two(range.start.month)} a ${_two(range.end.day)}/${_two(range.end.month)}';

String _clockLabel(DateTime time) => '${_two(time.hour)}:${_two(time.minute)}';

String _percent(double share) => '${(share * 100).round()}%';

String _formatValue(double value) {
  final rounded = value.roundToDouble();
  if ((value - rounded).abs() < 0.05) return rounded.toInt().toString();
  return value.toStringAsFixed(1).replaceAll('.', ',');
}
