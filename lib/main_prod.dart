import 'package:samapoche/env.dart';
import 'package:samapoche/main.dart' as app;

/// Point d'entrée flavor PROD (production).
void main() => app.runAppWith(
  flavor: Flavor.prod,
  apiBaseUrl: const String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://api.samapoche.sn',
  ),
);
