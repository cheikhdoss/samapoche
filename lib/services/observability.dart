import 'dart:async';
import 'dart:ui' show PlatformDispatcher;

import 'package:logging/logging.dart';

import 'package:samapoche/env.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

/// Configuration de l'observabilité.
///
/// Sentry est activé uniquement si un DSN est fourni au build :
///   flutter run --dart-define=SENTRY_DSN=https://...@ingest.sentry.io/...
class Observability {
  static const _dsn = String.fromEnvironment('SENTRY_DSN');
  static bool get enabled => _dsn.isNotEmpty;

  static bool _initialized = false;

  static Future<void> init({
    List<Integration>? integrations,
    String? environment,
  }) async {
    setupGlobalLogging();
    if (!enabled) {
      Logger('Observability').info('Sentry désactivé (aucun SENTRY_DSN)');
      return;
    }
    await SentryFlutter.init((options) {
      options
        ..dsn = _dsn
        ..tracesSampleRate = 0.1;
      if (environment != null) options.environment = environment;
      integrations?.forEach(options.addIntegration);
    }, appRunner: () {});
    _initialized = true;
    Logger('Observability').info('Sentry initialisé ($environment)');
  }

  static void capture(Object error, StackTrace stackTrace) {
    if (!_initialized) return;
    unawaited(Sentry.captureException(error, stackTrace: stackTrace));
  }

  static void captureMessage(String message) {
    if (!_initialized) return;
    unawaited(Sentry.captureMessage(message));
  }
}

/// Configure le niveau du logger racine (hierarchical logging désactivé).
void setupGlobalLogging() {
  Logger.root.level = AppEnv.debug ? Level.FINE : Level.INFO;
}

/// Logger simple avec capture Sentry intégrée.
Logger buildLogger(String name) => Logger(name);

/// Handler de dernier recours (erreurs non rattrapées).
void setupGlobalErrorHandlers() {
  PlatformDispatcher.instance.onError = (error, stack) {
    Observability.capture(error, stack);
    return true;
  };
}
