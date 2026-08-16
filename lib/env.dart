/// Environnements de build (flavors) et configurations associées.
///
/// Chaque flavor possède son point d'entrée dédié :
///   - dev     → `lib/main_dev.dart`     (backend local)
///   - staging → `lib/main_staging.dart` (pré-production)
///   - prod    → `lib/main_prod.dart`    (production)
///
/// Les URLs par défaut peuvent être surchargées au build :
///   flutter run -t lib/main_staging.dart \
///     --dart-define=API_BASE_URL=http://localhost:8000
///
/// Côté Android, les flavors sont déclarées dans
/// `android/app/build.gradle.kts` (applicationIdSuffix + resValue app_name).
enum Flavor {
  dev('Développement', 'http://localhost:8000'),
  staging('Staging', 'https://api-staging.samapoche.sn'),
  prod('Production', 'https://api.samapoche.sn');

  const Flavor(this.label, this.defaultApiBaseUrl);

  /// Libellé affiché dans le diagnostic d'environnement.
  final String label;

  /// URL de l'API par défaut de ce flavor (surchargable via API_BASE_URL).
  final String defaultApiBaseUrl;

  bool get isProd => this == Flavor.prod;
}

/// Configuration d'environnement effective, exposée via Provider.
class AppConfig {
  const AppConfig({required this.flavor, required this.apiBaseUrl});

  final Flavor flavor;
  final String apiBaseUrl;

  bool get isProd => flavor.isProd;
}

/// Constantes de build partagées (dart-define).
abstract final class AppEnv {
  /// Active la verbosité des logs (désactivée en release).
  static const debug = bool.fromEnvironment('APP_DEBUG', defaultValue: true);
}
