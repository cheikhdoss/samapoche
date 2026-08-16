import 'package:samapoche/models/dto.dart';
import 'package:samapoche/services/api_client.dart';
import 'package:samapoche/services/cache.dart';

/// Budgets mensuels par catégorie (lecture + mise à jour).
///
/// Le DTO est ici la forme de présentation : aucun transcodage nécessaire,
/// les écrans n'affichent que `id`, `categoryName`, `amount` et `spent`.
class BudgetsRepository {
  final Api _api;
  final CacheStore _cache;

  BudgetsRepository({required this._api, required this._cache});

  Future<List<BudgetStatusDto>> fetch() async {
    final list = await _api.budgets();
    await _cache.storeBudgets([for (final b in list) b.toJson()]);
    return list;
  }

  Future<BudgetResponseDto> update(int id, {required double amount}) =>
      _api.updateBudget(id, amount: amount);

  Future<BudgetResponseDto> create({
    required int categoryId,
    required double amount,
    required int month,
    required int year,
  }) => _api.createBudget(
    categoryId: categoryId,
    amount: amount,
    month: month,
    year: year,
  );
}
