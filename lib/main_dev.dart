import 'package:samapoche/env.dart';
import 'package:samapoche/main.dart' as app;

/// Point d'entrée flavor DEV (backend local).
void main() => app.runAppWith(
  flavor: Flavor.dev,
  apiBaseUrl: const String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:8000',
  ),
);
