import 'package:samapoche/domain/models.dart';
import 'package:samapoche/services/api_client.dart';
import 'package:samapoche/services/cache.dart';
import 'package:samapoche/services/token_storage.dart';

/// Session : identifiants, token JWT et profil local.
///
/// Sur la frontière avec le réseau, les DTO sont convertis en modèles de
/// domaine ([UserProfile]) : plus aucun écran ne manipule de DTO.
class AuthRepository {
  final Api _api;
  final CacheStore _cache;
  final TokenStorage _tokenStorage;

  AuthRepository({
    required this._api,
    required this._cache,
    required this._tokenStorage,
  });

  /// Token JWT vivant en mémoire (l'écriture chiffrée est assurée par
  /// [TokenStorage] à chaque connexion/déconnexion).
  String? get token => _api.token;

  bool get hasToken => token != null && token!.isNotEmpty;

  set token(String? value) => _api.token = value;

  /// Réhydrate le token persisté (restart de l'application).
  Future<String?> restoreToken() => _tokenStorage.read();

  Future<String?> signup({
    required String email,
    required String password,
    required String fullName,
  }) async {
    try {
      final token = await _api.register(
        email: email,
        password: password,
        fullName: fullName,
      );
      await _persistToken(token.accessToken);
      return null;
    } on ApiException catch (e) {
      return e.message;
    }
  }

  Future<String?> login({
    required String email,
    required String password,
  }) async {
    try {
      final token = await _api.login(email: email, password: password);
      await _persistToken(token.accessToken);
      return null;
    } on ApiException catch (e) {
      return e.message;
    }
  }

  /// Persiste un token dans le stockage chiffré (connexion, migration v1).
  Future<void> persistToken(String accessToken) =>
      _tokenStorage.write(accessToken);

  Future<void> _persistToken(String accessToken) async {
    token = accessToken;
    await persistToken(accessToken);
  }

  /// Ferme la session : token en mémoire et chiffré, et données locales.
  Future<void> logout() async {
    token = null;
    await _tokenStorage.delete();
    await _cache.clearUserData();
  }

  /// Profil courant depuis le serveur (et rafraîchi en cache local).
  Future<UserProfile> me() async {
    final user = UserProfile.fromDto(await _api.me());
    await _cache.storeUser(user.toJson());
    return user;
  }

  UserProfile? cachedUser() {
    final raw = _cache.user;
    if (raw == null) return null;
    return UserProfile.fromJson(raw.cast<String, dynamic>());
  }

  Future<void> storeLocalUser(UserProfile user) async =>
      _cache.storeUser(user.toJson());
}
