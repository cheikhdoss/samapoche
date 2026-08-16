import 'package:samapoche/domain/models.dart';
import 'package:samapoche/models/dto.dart';
import 'package:samapoche/services/api_client.dart';
import 'package:samapoche/services/cache.dart';

/// Catalogue des catégories et de leurs identifiants serveur.
///
/// Le mapping `id → nom` est la seule source de vérité pour transcoder les
/// transactions ([Txn]) — il est rafraîchi à chaque synchronisation et peut
/// être restauré hors-ligne depuis le cache.
class CategoriesRepository {
  final Api _api;
  final CacheStore _cache;

  CategoriesRepository({required this._api, required this._cache});

  /// Référentiel frais (serveur) + cache rafraîchi.
  Future<Map<int, String>> names() async {
    final list = await _api.categories();
    await _cache.storeCategories([for (final c in list) c.toJson()]);
    return _byId(list);
  }

  /// Dernière image connue (hors-ligne), `null` si jamais chargée.
  Map<int, String>? cachedNames() {
    final raw = _cache.categories;
    if (raw == null) return null;
    return _byId([
      for (final e in raw)
        CategoryDto.fromJson(Map<String, dynamic>.from(e as Map)),
    ]);
  }

  static Map<int, String> _byId(List<CategoryDto> list) => {
    for (final c in list) c.id: c.name,
  };
}
