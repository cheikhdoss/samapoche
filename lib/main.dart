import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

import 'package:samapoche/l10n/l10n.dart';
import 'package:samapoche/router.dart';
import 'package:samapoche/services/api_client.dart';
import 'package:samapoche/services/cache.dart';
import 'package:samapoche/services/observability.dart';
import 'package:samapoche/services/token_storage.dart';
import 'package:samapoche/state/app_state.dart';
import 'package:samapoche/theme.dart';

/// Point d'entrée par défaut (flavor dev).
void main() => runAppWith(
  apiBaseUrl: const String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:8000',
  ),
);

/// Bootstrap partagé par les flavors (dev / staging / prod).
Future<void> runAppWith({required String apiBaseUrl}) async {
  WidgetsFlutterBinding.ensureInitialized();
  await Observability.init();
  setupGlobalErrorHandlers();

  final appDir = await getApplicationSupportDirectory();
  await Hive.initFlutter(appDir.path);

  final api = Api(baseUrl: apiBaseUrl);
  final cache = HiveCache();
  await cache.init();
  final state = AppState(api: api, cache: cache, tokenStorage: TokenStorage());

  runApp(SamaPocheApp(state: state));
}

class SamaPocheApp extends StatefulWidget {
  final AppState state;
  const SamaPocheApp({super.key, required this.state});

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
    return ChangeNotifierProvider<AppState>.value(
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
    );
  }
}
