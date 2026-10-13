import 'dart:convert';

import 'package:drift/drift.dart';

import 'orva_repository.dart';

/// Ingredient input for a planned or consumed meal. Snapshot-backed entries
/// preserve the original recorded nutrition even if the catalogue later changes.
class FoodQuantity {
  const FoodQuantity({
    required this.foodId,
    required this.quantity,
    this.snapshotName,
    this.snapshotUnit,
    this.snapshotQuantity,
    this.snapshotCalories,
    this.snapshotProteinG,
    this.snapshotCarbohydratesG,
    this.snapshotFatG,
    this.snapshotFibreG,
  });

  final String? foodId;
  final double quantity;
  final String? snapshotName;
  final String? snapshotUnit;
  final double? snapshotQuantity;
  final Object? snapshotCalories;
  final Object? snapshotProteinG;
  final Object? snapshotCarbohydratesG;
  final Object? snapshotFatG;
  final Object? snapshotFibreG;
}

double? _nutritionScale(Object? perReference, double quantity, double referenceAmount) {
  if (perReference is! num) return null;
  return perReference.toDouble() * quantity / referenceAmount;
}

double? _nutrientTotal(List<Map<String, Object?>> items, String key) {
  final known = items.where((item) => item[key] is num).toList();
  if (known.isEmpty) return null;
  return known.fold<double>(
    0,
    (sum, item) => sum + (item[key] as num).toDouble(),
  );
}

/// Catalog, meal planning and consumption are independent by design. A meal
/// being planned never creates a consumption record automatically.
extension NutritionRepository on OrvaRepository {
  Future<List<Map<String, Object?>>> getFoods({String? search}) {
    final query = search?.trim() ?? '';
    if (query.isEmpty) {
      return rows('SELECT * FROM foods ORDER BY name COLLATE NOCASE');
    }
    return rows(
      'SELECT * FROM foods WHERE name LIKE ? OR brand LIKE ? ORDER BY name COLLATE NOCASE',
      [Variable.withString('%$query%'), Variable.withString('%$query%')],
    );
  }

  Future<void> saveFood({
    String? id,
    required String name,
    String? brand,
    double referenceAmount = 100,
    String referenceUnit = 'g',
    double? calories,
    double? proteinG,
    double? carbohydratesG,
    double? fatG,
    double? fibreG,
    String nutritionSource = 'manual',
    String note = '',
  }) async {
    if (name.trim().isEmpty) throw ArgumentError('Informe o nome do alimento.');
    if (!referenceAmount.isFinite || referenceAmount <= 0) {
      throw ArgumentError('A quantidade de referência precisa ser maior que zero.');
    }
    for (final value in [calories, proteinG, carbohydratesG, fatG, fibreG]) {
      if (value != null && (!value.isFinite || value < 0)) {
        throw ArgumentError('Valores nutricionais devem ser números não negativos.');
      }
    }
    final now = timestamp();
    if (id == null) {
      await execute('''
        INSERT INTO foods(id,name,brand,reference_amount,reference_unit,calories,protein_g,
          carbohydrates_g,fat_g,fibre_g,nutrition_source,note,created_at,updated_at)
        VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?,?)
      ''', [newId(),name.trim(),_trimOrNull(brand),referenceAmount,referenceUnit.trim(),calories,
        proteinG,carbohydratesG,fatG,fibreG,nutritionSource.trim(),note.trim(),now,now]);
    } else {
      await execute('''
        UPDATE foods SET name=?,brand=?,reference_amount=?,reference_unit=?,calories=?,
          protein_g=?,carbohydrates_g=?,fat_g=?,fibre_g=?,nutrition_source=?,note=?,updated_at=?
        WHERE id=?
      ''', [name.trim(),_trimOrNull(brand),referenceAmount,referenceUnit.trim(),calories,
        proteinG,carbohydratesG,fatG,fibreG,nutritionSource.trim(),note.trim(),now,id]);
    }
  }

  Future<void> deleteFood(String id) async {
    // Snapshot fields on historical and planned items survive; only their
    // optional link to the reusable catalogue entry is nulled by SQLite.
    await execute('DELETE FROM foods WHERE id=?', [id]);
  }

  Future<List<Map<String, Object?>>> getMealPlans({bool activeOnly = true}) =>
      rows('SELECT * FROM meal_plans ${activeOnly ? 'WHERE is_active=1' : ''} ORDER BY planned_minute,title COLLATE NOCASE');

  Future<List<Map<String, Object?>>> getMealPlansForDate(DateTime date) async {
    final key = dateKey(date);
    final weekday = date.weekday;
    final plans = await getMealPlans();
    return plans.where((plan) {
      final recurrence = plan['recurrence'] as String? ?? 'once';
      final start = plan['start_date'] as String?;
      final end = plan['end_date'] as String?;
      if (start != null && key.compareTo(start) < 0) return false;
      if (end != null && key.compareTo(end) > 0) return false;
      switch (recurrence) {
        case 'once':
          return plan['planned_date'] == key;
        case 'daily':
          return true;
        case 'weekly':
        case 'custom':
          try {
            final days = (jsonDecode(plan['weekdays_json'] as String) as List)
                .whereType<num>().map((value) => value.toInt()).toSet();
            return days.contains(weekday);
          } catch (_) {
            return false;
          }
        default:
          return false;
      }
    }).toList();
  }

  Future<void> saveMealPlan({
    String? id,
    required String title,
    required String mealType,
    required String recurrence,
    String? plannedDate,
    List<int> weekdays = const [],
    String? startDate,
    String? endDate,
    int? plannedMinute,
    int? durationMinutes,
    String note = '',
    bool active = true,
  }) async {
    if (title.trim().isEmpty) throw ArgumentError('Informe o nome da refeição planejada.');
    if (!const {'once','daily','weekly','custom'}.contains(recurrence)) {
      throw ArgumentError('Recorrência de refeição inválida.');
    }
    if (recurrence == 'once' && plannedDate == null) {
      throw ArgumentError('Escolha a data da refeição.');
    }
    if ((recurrence == 'weekly' || recurrence == 'custom') && weekdays.isEmpty) {
      throw ArgumentError('Escolha ao menos um dia da semana.');
    }
    if (plannedMinute != null && (plannedMinute < 0 || plannedMinute >= 1440)) {
      throw ArgumentError('Horário da refeição inválido.');
    }
    if (durationMinutes != null &&
        (durationMinutes < 1 || durationMinutes > 1440)) {
      throw ArgumentError('A duração planejada deve estar entre 1 e 1440 minutos.');
    }
    if (durationMinutes != null && plannedMinute == null) {
      throw ArgumentError('Defina um horário inicial antes de informar a duração.');
    }
    if (durationMinutes != null && plannedMinute! + durationMinutes > 1440) {
      throw ArgumentError('O intervalo da refeição não pode ultrapassar a meia-noite. Escolha outro horário ou duração.');
    }
    if (startDate != null && endDate != null && endDate.compareTo(startDate) < 0) {
      throw ArgumentError('A data final deve ser posterior à data inicial.');
    }
    final now = timestamp();
    if (id == null) {
      await execute('''
        INSERT INTO meal_plans(id,title,meal_type,recurrence,planned_date,weekdays_json,start_date,
          end_date,planned_minute,duration_minutes,note,is_active,created_at,updated_at)
        VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?,?)
      ''', [newId(),title.trim(),mealType,recurrence,plannedDate,jsonEncode(weekdays.toSet().toList()..sort()),
        _trimOrNull(startDate),_trimOrNull(endDate),plannedMinute,durationMinutes,note.trim(),active?1:0,now,now]);
    } else {
      await execute('''
        UPDATE meal_plans SET title=?,meal_type=?,recurrence=?,planned_date=?,weekdays_json=?,
          start_date=?,end_date=?,planned_minute=?,duration_minutes=?,note=?,is_active=?,updated_at=? WHERE id=?
      ''', [title.trim(),mealType,recurrence,plannedDate,jsonEncode(weekdays.toSet().toList()..sort()),
        _trimOrNull(startDate),_trimOrNull(endDate),plannedMinute,durationMinutes,note.trim(),active?1:0,now,id]);
    }
  }

  /// Returns only meals with both a real planned start and explicit
  /// duration. The returned intervals can enter planned-time aggregation;
  /// they are not consumption records and do not imply that the meal happened.
  Future<List<Map<String, Object?>>> getMealPlanTimeBlocksForDate(DateTime date) async {
    final plans = await getMealPlansForDate(date);
    final blocks = <Map<String, Object?>>[];
    for (final plan in plans) {
      final startValue = plan['planned_minute'];
      final durationValue = plan['duration_minutes'];
      if (startValue is! num || durationValue is! num) continue;
      final start = startValue.toInt();
      final duration = durationValue.toInt();
      final end = start + duration;
      if (start < 0 || start >= 1440 || duration <= 0 || end > 1440) continue;
      blocks.add({
        'id': 'meal-plan:${plan['id']}',
        'meal_plan_id': plan['id'],
        'title': plan['title'],
        'category': 'Alimentação',
        'start_minute': start,
        'end_minute': end,
        'block_kind': 'mealPlan',
        'planned_date': dateKey(date),
        'meal_type': plan['meal_type'],
      });
    }
    return blocks;
  }

  Future<void> setMealPlanActive(String id, bool active) => execute(
    'UPDATE meal_plans SET is_active=?,updated_at=? WHERE id=?',
    [active ? 1 : 0,timestamp(),id],
  );

  Future<void> deleteMealPlan(String id) => execute('DELETE FROM meal_plans WHERE id=?',[id]);

  Future<List<Map<String, Object?>>> getMealPlanItems(String planId) => rows(
    'SELECT * FROM meal_plan_items WHERE meal_plan_id=? ORDER BY order_index',
    [Variable.withString(planId)],
  );

  Future<void> addMealPlanItem({
    required String mealPlanId,
    required String foodId,
    required double quantity,
    int orderIndex = 0,
  }) async {
    if (!quantity.isFinite || quantity <= 0) throw ArgumentError('A quantidade precisa ser positiva.');
    final foods = await rows('SELECT * FROM foods WHERE id=?',[Variable.withString(foodId)]);
    if (foods.isEmpty) throw ArgumentError('Alimento não encontrado.');
    final food = foods.first;
    final reference = (food['reference_amount'] as num).toDouble();
    await execute('''
      INSERT INTO meal_plan_items(id,meal_plan_id,food_id,food_name_snapshot,quantity,unit,
        calories,protein_g,carbohydrates_g,fat_g,fibre_g,order_index)
      VALUES(?,?,?,?,?,?,?,?,?,?,?,?)
    ''', [newId(),mealPlanId,foodId,food['name'],quantity,food['reference_unit'],
      _nutritionScale(food['calories'],quantity,reference),
      _nutritionScale(food['protein_g'],quantity,reference),
      _nutritionScale(food['carbohydrates_g'],quantity,reference),
      _nutritionScale(food['fat_g'],quantity,reference),
      _nutritionScale(food['fibre_g'],quantity,reference),orderIndex]);
  }

  Future<void> deleteMealPlanItem(String id) => execute('DELETE FROM meal_plan_items WHERE id=?',[id]);

  Future<List<Map<String, Object?>>> getFoodConsumptionsForDate(DateTime date) => rows('''
    SELECT c.*,
      (SELECT COUNT(*) FROM food_consumption_items i WHERE i.consumption_id=c.id) AS item_count,
      (SELECT SUM(i.calories) FROM food_consumption_items i WHERE i.consumption_id=c.id) AS known_calories,
      (SELECT COUNT(*) FROM food_consumption_items i WHERE i.consumption_id=c.id AND i.calories IS NULL) AS calories_missing
    FROM food_consumptions c WHERE c.consumed_date=?
    ORDER BY c.consumed_minute,c.created_at
  ''',[Variable.withString(dateKey(date))]);

  Future<List<Map<String, Object?>>> getFoodConsumptionItems(String consumptionId) => rows(
    'SELECT * FROM food_consumption_items WHERE consumption_id=? ORDER BY order_index',
    [Variable.withString(consumptionId)],
  );

  Future<void> saveFoodConsumption({
    String? id,
    required DateTime consumedDate,
    int? consumedMinute,
    required String mealType,
    required String title,
    String note = '',
    List<FoodQuantity> items = const [],
  }) async {
    if (title.trim().isEmpty) throw ArgumentError('Informe o nome da refeição consumida.');
    if (consumedMinute != null && (consumedMinute < 0 || consumedMinute >= 1440)) {
      throw ArgumentError('Horário de consumo inválido.');
    }

    final normalizedItems = <Map<String, Object?>>[];
    for (final item in items) {
      if (!item.quantity.isFinite || item.quantity <= 0) {
        throw ArgumentError('A quantidade de cada alimento precisa ser positiva.');
      }

      // When editing an existing record, keep its nutrition snapshot rather
      // than silently recalculating history against today's food catalogue.
      if (item.snapshotName != null && item.snapshotUnit != null) {
        final baseQuantity = item.snapshotQuantity;
        if (baseQuantity == null || !baseQuantity.isFinite || baseQuantity <= 0) {
          throw ArgumentError('O snapshot do alimento tem uma quantidade inválida.');
        }
        normalizedItems.add({
          'food_id': item.foodId,
          'food_name_snapshot': item.snapshotName,
          'quantity': item.quantity,
          'unit': item.snapshotUnit,
          'calories': _nutritionScale(item.snapshotCalories, item.quantity, baseQuantity),
          'protein_g': _nutritionScale(item.snapshotProteinG, item.quantity, baseQuantity),
          'carbohydrates_g': _nutritionScale(item.snapshotCarbohydratesG, item.quantity, baseQuantity),
          'fat_g': _nutritionScale(item.snapshotFatG, item.quantity, baseQuantity),
          'fibre_g': _nutritionScale(item.snapshotFibreG, item.quantity, baseQuantity),
        });
        continue;
      }

      final foodId = item.foodId;
      if (foodId == null) {
        throw ArgumentError('Selecione um alimento do catálogo ou forneça um snapshot preservado.');
      }
      final found = await rows('SELECT * FROM foods WHERE id=?', [Variable.withString(foodId)]);
      if (found.isEmpty) throw ArgumentError('Um dos alimentos selecionados não existe mais.');
      final food = found.first;
      final reference = (food['reference_amount'] as num).toDouble();
      normalizedItems.add({
        'food_id': food['id'],
        'food_name_snapshot': food['name'],
        'quantity': item.quantity,
        'unit': food['reference_unit'],
        'calories': _nutritionScale(food['calories'], item.quantity, reference),
        'protein_g': _nutritionScale(food['protein_g'], item.quantity, reference),
        'carbohydrates_g': _nutritionScale(food['carbohydrates_g'], item.quantity, reference),
        'fat_g': _nutritionScale(food['fat_g'], item.quantity, reference),
        'fibre_g': _nutritionScale(food['fibre_g'], item.quantity, reference),
      });
    }

    final now = timestamp();
    final consumptionId = id ?? newId();
    await db.transaction(() async {
      if (id == null) {
        await execute('''
          INSERT INTO food_consumptions(id,consumed_date,consumed_minute,meal_type,title,note,created_at,updated_at)
          VALUES(?,?,?,?,?,?,?,?)
        ''', [consumptionId,dateKey(consumedDate),consumedMinute,mealType,title.trim(),note.trim(),now,now]);
      } else {
        await execute('''
          UPDATE food_consumptions SET consumed_date=?,consumed_minute=?,meal_type=?,title=?,note=?,updated_at=?
          WHERE id=?
        ''', [dateKey(consumedDate),consumedMinute,mealType,title.trim(),note.trim(),now,consumptionId]);
        await execute('DELETE FROM food_consumption_items WHERE consumption_id=?', [consumptionId]);
      }
      for (var i = 0; i < normalizedItems.length; i++) {
        final item = normalizedItems[i];
        await execute('''
          INSERT INTO food_consumption_items(id,consumption_id,food_id,food_name_snapshot,quantity,unit,
            calories,protein_g,carbohydrates_g,fat_g,fibre_g,order_index)
          VALUES(?,?,?,?,?,?,?,?,?,?,?,?)
        ''', [
          newId(),consumptionId,item['food_id'],item['food_name_snapshot'],item['quantity'],
          item['unit'],item['calories'],item['protein_g'],item['carbohydrates_g'],item['fat_g'],
          item['fibre_g'],i,
        ]);
      }
    });
  }

  Future<void> deleteFoodConsumption(String id) => execute('DELETE FROM food_consumptions WHERE id=?',[id]);

  Future<Map<String, Object?>> getPlannedNutritionSummary(DateTime date) async {
    final plans = await getMealPlansForDate(date);
    final items = <Map<String, Object?>>[];
    for (final plan in plans) {
      items.addAll(await getMealPlanItems(plan['id'] as String));
    }
    final result = <String, Object?>{
      'planCount': plans.length,
      'itemCount': items.length,
    };
    for (final nutrient in const [
      'calories',
      'protein_g',
      'carbohydrates_g',
      'fat_g',
      'fibre_g',
    ]) {
      result[nutrient] = _nutrientTotal(items, nutrient);
      result['${nutrient}Missing'] =
          items.where((item) => item[nutrient] == null).length;
    }
    result['isPartial'] = items.any((item) =>
        const ['calories', 'protein_g', 'carbohydrates_g', 'fat_g']
            .any((key) => item[key] == null));
    return result;
  }

  Future<Map<String,Object?>> getNutritionSummary(DateTime date) async {
    final items=await rows('''
      SELECT i.* FROM food_consumption_items i
      JOIN food_consumptions c ON c.id=i.consumption_id
      WHERE c.consumed_date=?
    ''',[Variable.withString(dateKey(date))]);
    final result=<String,Object?>{
      'itemCount':items.length,
      'consumptionCount':(await getFoodConsumptionsForDate(date)).length,
    };
    for(final nutrient in const ['calories','protein_g','carbohydrates_g','fat_g','fibre_g']){
      result[nutrient]=_nutrientTotal(items,nutrient);
      result['${nutrient}Missing']=items.where((item)=>item[nutrient]==null).length;
    }
    result['isPartial']=items.any((item)=>const ['calories','protein_g','carbohydrates_g','fat_g'].any((key)=>item[key]==null));
    return result;
  }
}

String? _trimOrNull(String? value) =>
    value == null || value.trim().isEmpty ? null : value.trim();
