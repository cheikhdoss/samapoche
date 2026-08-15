import 'package:samapoche/env.dart';
import 'package:samapoche/main.dart' as app;

/// Point d'entrée flavor STAGING (pré-production).
void main() => app.runAppWith(
  flavor: Flavor.staging,
  apiBaseUrl: const String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://api-staging.samapoche.sn',
  ),
);
