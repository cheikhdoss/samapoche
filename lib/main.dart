import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

import 'package:samapoche/env.dart';
import 'package:samapoche/l10n/l10n.dart';
import 'package:samapoche/router.dart';
import 'package:samapoche/services/api_client.dart';
import 'package:samapoche/services/cache.dart';
import 'package:samapoche/services/observability.dart';
import 'package:samapoche/services/token_storage.dart';
import 'package:samapoche/state/app_state.dart';
import 'package:samapoche/theme.dart';

/// Point d'entrée par défaut (flavor dev, voir `lib/main_dev.dart`).
void main() => runAppWith(
  flavor: Flavor.dev,
  apiBaseUrl: const String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:8000',
  ),
);

/// Bootstrap partagé par les flavors (dev / staging / prod).
///
/// [client] permet d'injecter un faux backend dans les tests d'intégration.
Future<void> runAppWith({
  required Flavor flavor,
  required String apiBaseUrl,
  http.Client? client,
}) async {
  WidgetsFlutterBinding.ensureInitialized();
  await Observability.init(environment: flavor.name);
  setupGlobalErrorHandlers();

  if (kIsWeb) {
    Hive.init(null);
  } else {
    final appDir = await getApplicationSupportDirectory();
    await Hive.initFlutter(appDir.path);
  }

  final api = Api(baseUrl: apiBaseUrl, client: client);
  final cache = HiveCache();
  await cache.init();
  final state = AppState.create(
    api: api,
    cache: cache,
    tokenStorage: TokenStorage(),
  );

  runApp(
    SamaPocheApp(
      state: state,
      config: AppConfig(flavor: flavor, apiBaseUrl: apiBaseUrl),
    ),
  );
}

class SamaPocheApp extends StatefulWidget {
  final AppState state;
  final AppConfig config;
  const SamaPocheApp({
    super.key,
    required this.state,
    this.config = const AppConfig(flavor: Flavor.dev, apiBaseUrl: ''),
  });

  @override
  State<SamaPocheApp> createState() => _SamaPocheAppState();
}

class _SamaPocheAppState extends State<SamaPocheApp> {
  late final AppState _state = widget.state;
  late final GoRouter _router = AppRouter.create(_state);

  @override
  void initState() {
    super.initState();
    unawaited(_state.init());
  }

  @override
  void dispose() {
    _router.dispose();
    _state.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Provider<AppConfig>.value(
      value: widget.config,
      child: ChangeNotifierProvider<AppState>.value(
        value: _state,
        child: ListenableBuilder(
          listenable: _state,
          builder: (context, _) {
            return MaterialApp.router(
              title: 'SamaPoche',
              debugShowCheckedModeBanner: false,
              theme: AppTheme.light(),
              darkTheme: AppTheme.dark(),
              themeMode: _state.darkMode ? ThemeMode.dark : ThemeMode.light,
              locale: const Locale('fr'),
              supportedLocales: AppLocalizations.supportedLocales,
              localizationsDelegates: const [
                AppLocalizations.delegate,
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              routerConfig: _router,
            );
          },
        ),
      ),
    );
  }
}
