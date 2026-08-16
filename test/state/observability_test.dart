import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/foundation.dart' show FlutterError;
import 'package:flutter_test/flutter_test.dart';
import 'package:logging/logging.dart';
import 'package:samapoche/env.dart';
import 'package:samapoche/services/observability.dart';

void main() {
  group('Observability', () {
    test('Sentry désactivé sans SENTRY_DSN → init() sans crash', () async {
      expect(Observability.enabled, isFalse);

      await Observability.init(environment: 'dev');
    });

    test('capture sans initialisation → no-op', () {
      Observability.capture(StateError('x'), StackTrace.current);
      Observability.captureMessage('message');
    });

    test('buildLogger → logger nommé', () {
      expect(buildLogger('AppState').name, 'AppState');
    });

    test('handler d\'erreur global capte et absorbe', () {
      setupGlobalErrorHandlers();
      final handled = PlatformDispatcher.instance.onError!(
        FlutterError('boom'),
        StackTrace.current,
      );
      expect(handled, isTrue);
    });
  });

  group('setupGlobalLogging', () {
    test('débogage (dev) → niveau FINE du logger racine', () {
      Logger.root.level = Level.WARNING;
      setupGlobalLogging();
      expect(Logger.root.level, AppEnv.debug ? Level.FINE : Level.INFO);
    });
  });
}
