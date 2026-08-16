import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:logging/logging.dart';
import 'package:samapoche/services/api_client.dart' show Api;

/// Stockage sécurisé du token JWT (Keystore / Keychain / DPAPI).
///
/// Le token n'est plus persisté dans SharedPreferences : il vit en mémoire
/// dans [Api.token] et uniquement chiffré au repos ici.
class TokenStorage {
  static const _key = 'samapoche_jwt';

  final FlutterSecureStorage _storage;
  final Logger _log = Logger('TokenStorage');

  TokenStorage({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  Future<String?> read() async {
    try {
      final v = await _storage.read(key: _key);
      return (v == null || v.isEmpty) ? null : v;
    } on Exception catch (e) {
      _log.warning('Lecture du token chiffré impossible: $e');
      return null;
    }
  }

  Future<void> write(String token) async {
    try {
      await _storage.write(key: _key, value: token);
    } on Exception catch (e) {
      _log.warning('Écriture du token chiffré impossible: $e');
    }
  }

  Future<void> delete() async {
    try {
      await _storage.delete(key: _key);
    } on Exception catch (e) {
      _log.warning('Suppression du token chiffré impossible: $e');
    }
  }
}
