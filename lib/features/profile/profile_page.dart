import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/database/orva_repository.dart';
import '../../core/theme/orva_theme.dart';
import '../../core/widgets/orva_widgets.dart';

const _genderOptions = <String>['Feminino', 'Masculino', 'Não binário', 'Prefiro não informar', 'Outro'];
final _dateFormat = DateFormat('dd/MM/yyyy');

class ProfilePage extends ConsumerStatefulWidget {
  const ProfilePage({super.key});
  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage> {
  final _name = TextEditingController();
  final _height = TextEditingController();
  DateTime? _birthDate;
  String? _gender;
  bool _loading = true;
  bool _busy = false;
  List<Map<String, Object?>> _weightEntries = const [];

  @override
  void initState() { super.initState(); _load(); }

  @override
  void dispose() { _name.dispose(); _height.dispose(); super.dispose(); }

  Future<void> _load() async {
    try {
      final repo = ref.read(repositoryProvider);
      final profile = await repo.getProfile();
      final entries = await repo.getWeightEntries();
      if (!mounted) return;
      setState(() {
        _name.text = profile['profile_name'] ?? '';
        final birth = profile['profile_birth_date'];
        _birthDate = birth != null && birth.isNotEmpty ? DateTime.tryParse(birth) : null;
        final height = profile['profile_height_cm'];
        _height.text = height != null && height.isNotEmpty ? height : '';
        _gender = profile['profile_gender']?.isNotEmpty == true ? profile['profile_gender'] : null;
        _weightEntries = entries;
        _loading = false;
      });
    } catch (error) {
      if (mounted) { setState(() => _loading = false); showOrvaError(context, error); }
    }
  }

  int? get _age => _birthDate == null ? null : ref.read(repositoryProvider).ageInYears(_birthDate!);

  double? get _latestWeight => _weightEntries.isEmpty ? null : (_weightEntries.first['weight_kg'] as num).toDouble();

  double? get _heightCm => double.tryParse(_height.text.replaceAll(',', '.'));

  Future<void> _pickBirthDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _birthDate ?? DateTime(2000, 1, 1),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _birthDate = picked);
  }

  Future<void> _save() async {
    setState(() => _busy = true);
    try {
      final height = _height.text.trim().isEmpty ? null : double.tryParse(_height.text.replaceAll(',', '.'));
      if (_height.text.trim().isNotEmpty && height == null) {
        throw const FormatException('Altura inválida. Use um número, por exemplo 172.');
      }
      await ref.read(repositoryProvider).saveProfile(
            name: _name.text,
            birthDateIso: _birthDate == null ? null : DateFormat('yyyy-MM-dd').format(_birthDate!),
            heightCm: height,
            gender: _gender,
          );
      if (mounted) showOrvaMessage(context, 'Perfil salvo neste dispositivo.');
    } catch (error) {
      if (mounted) showOrvaError(context, error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _addWeightEntry() async {
    final weightController = TextEditingController();
    var date = DateTime.now();
    final result = await showDialog<double>(
      context: context,
      builder: (context) => StatefulBuilder(builder: (context, setDialogState) {
        return AlertDialog(
          title: const Text('Registrar peso'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: weightController, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Peso (kg)'), autofocus: true),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: Text('Data: ${_dateFormat.format(date)}')),
              TextButton(
                onPressed: () async {
                  final picked = await showDatePicker(context: context, initialDate: date, firstDate: DateTime(1900), lastDate: DateTime.now());
                  if (picked != null) setDialogState(() => date = picked);
                },
                child: const Text('Alterar'),
              ),
            ]),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
            FilledButton(
              onPressed: () {
                final weight = double.tryParse(weightController.text.replaceAll(',', '.'));
                if (weight == null || weight <= 0) return;
                Navigator.pop(context, weight);
              },
              child: const Text('Salvar'),
            ),
          ],
        );
      }),
    );
    if (result == null) return;
    try {
      await ref.read(repositoryProvider).saveWeightEntry(measuredAt: date, weightKg: result);
      await _load();
    } catch (error) {
      if (mounted) showOrvaError(context, error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final age = _age;
    final weight = _latestWeight;
    final height = _heightCm;
    double? bmi;
    if (weight != null && height != null && height > 0) {
      bmi = ref.read(repositoryProvider).bodyMassIndex(weightKg: weight, heightCm: height);
    }
    final isMinor = age != null && age < 20;

    return Scaffold(
      appBar: AppBar(title: const Text('Perfil')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(padding: const EdgeInsets.fromLTRB(20, 10, 20, 28), children: [
              Text('Identidade', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 4),
              Text('Todos os campos são opcionais e ficam só neste dispositivo.', style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 14),
              TextField(controller: _name, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'Nome')),
              const SizedBox(height: 12),
              OrvaSurface(onTap: _pickBirthDate, child: Row(children: [
                const Icon(Icons.cake_outlined, color: OrvaColors.secondaryText),
                const SizedBox(width: 10),
                Expanded(child: Text(_birthDate == null ? 'Data de nascimento' : '${_dateFormat.format(_birthDate!)}${age != null ? ' · $age anos' : ''}')),
                const Icon(Icons.chevron_right_rounded, color: OrvaColors.tertiaryText),
              ])),
              const SizedBox(height: 12),
              TextField(controller: _height, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Altura (cm)')),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _gender,
                decoration: const InputDecoration(labelText: 'Gênero (opcional)'),
                items: _genderOptions.map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
                onChanged: (value) => setState(() => _gender = value),
              ),
              const SizedBox(height: 16),
              SizedBox(width: double.infinity, child: FilledButton(onPressed: _busy ? null : _save, child: _busy ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Salvar perfil'))),
              const SizedBox(height: 30),
              Row(children: [
                Expanded(child: Text('Peso e IMC', style: Theme.of(context).textTheme.titleLarge)),
                TextButton.icon(onPressed: _addWeightEntry, icon: const Icon(Icons.add, size: 18), label: const Text('Registrar')),
              ]),
              const SizedBox(height: 10),
              if (weight == null)
                const OrvaEmptyState(icon: Icons.monitor_weight_outlined, title: 'Nenhum peso registrado', message: 'Registre seu peso para acompanhar a evolução ao longo do tempo.', compact: true)
              else ...[
                OrvaSurface(child: Row(children: [
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Peso mais recente', style: Theme.of(context).textTheme.bodySmall),
                    Text('${weight.toStringAsFixed(1)} kg', style: orvaMonoStyle(fontSize: 22)),
                  ])),
                  if (bmi != null && !isMinor)
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('IMC', style: Theme.of(context).textTheme.bodySmall),
                      Text(bmi.toStringAsFixed(1), style: orvaMonoStyle(fontSize: 22)),
                    ])),
                ])),
                if (bmi != null && isMinor) ...[
                  const SizedBox(height: 10),
                  const OrvaSurface(child: Text('Como a idade informada é abaixo de 20 anos, o Orva não classifica o IMC usando as faixas de adultos — percentis por idade/sexo não estão implementados nesta etapa. Converse com um profissional de saúde para uma avaliação adequada.', style: TextStyle(color: OrvaColors.secondaryText))),
                ] else if (bmi != null) ...[
                  const SizedBox(height: 10),
                  const Text('O IMC é um indicador limitado e não substitui avaliação médica.', style: TextStyle(fontSize: 12, color: OrvaColors.tertiaryText)),
                ],
                const SizedBox(height: 14),
                ..._weightEntries.take(10).map((entry) {
                  final date = DateTime.tryParse(entry['measured_at'] as String? ?? '');
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: OrvaSurface(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10), child: Row(children: [
                      Expanded(child: Text(date == null ? '—' : _dateFormat.format(date))),
                      Text('${(entry['weight_kg'] as num).toDouble().toStringAsFixed(1)} kg', style: orvaMonoStyle()),
                    ])),
                  );
                }),
              ],
            ]),
    );
  }
}
