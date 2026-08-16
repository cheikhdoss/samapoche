import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:samapoche/env.dart';
import 'package:samapoche/main.dart' as app;
import 'package:samapoche/testing/fake_backend.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Parcours E2E complet : inscription → ajout de transaction → liste.
///
/// Deux modes :
///  - **Hermétique (défaut, utilisé par la CI)** : aucune `API_BASE_URL`
///    n'est fournie → un faux backend AFI (MockClient) est injecté ;
///    aucun serveur requis, test reproductible partout.
///  - **Backend réel** : fournir l'URL et lancer sur un device/émulateur :
///      flutter test integration_test -d `device` \
///        --dart-define=API_BASE_URL=http://10.0.2.2:8000
/// Bouton en bas de formulaire : scrolling d'abord (viewport headless CI).
Future<void> tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle(const Duration(milliseconds: 300));
  await tester.tap(finder);
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const envUrl = String.fromEnvironment('API_BASE_URL');
  final hermetic = envUrl.isEmpty;

  testWidgets(
    'E2E : inscription → ajout de transaction → liste (${hermetic ? 'hermétique' : 'backend réel'})',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final backend = hermetic ? TestBackend(TestControls()) : null;

      await app.runAppWith(
        flavor: Flavor.dev,
        apiBaseUrl: hermetic ? 'http://backend-hermetique.test' : envUrl,
        client: backend?.client,
      );
      await tester.pumpAndSettle();

      expect(find.text('Gérez mieux. Économisez plus.'), findsOneWidget);

      // Inscription
      await tester.tap(find.text('Créer un compte'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).at(0), 'E2E');
      await tester.enterText(find.byType(TextField).at(1), 'Test');
      await tester.enterText(find.byType(TextField).at(2), 'e2e@test.dev');
      await tester.enterText(find.byType(TextField).at(3), '+228 90000000');
      await tester.enterText(find.byType(TextField).at(4), 'Test1234!');
      await tester.enterText(find.byType(TextField).at(5), 'Test1234!');
      await tester.pumpAndSettle(const Duration(milliseconds: 300));

      await tapVisible(tester, find.textContaining("J'accepte les"));
      await tapVisible(tester, find.text("S'inscrire"));
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // Écran d'accueil (synchronisé avec le backend)
      expect(find.text('Répartition des dépenses'), findsOneWidget);

      // Ajout d'une transaction
      await tester.tap(find.byTooltip('Nouvelle transaction'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).at(0), '5000');
      await tester.enterText(find.byType(TextField).at(1), 'Test E2E');
      await tester.pumpAndSettle(const Duration(milliseconds: 300));
      await tapVisible(tester, find.text('Enregistrer'));
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // La transaction apparaît dans l'onglet Transactions
      await tester.tap(find.text('Transactions'));
      await tester.pumpAndSettle(const Duration(seconds: 3));

      expect(find.text('Test E2E'), findsOneWidget);

      // Retour à l'accueil via la barre du bas
      await tester.tap(find.text('Accueil'));
      await tester.pumpAndSettle();
      expect(find.text('Répartition des dépenses'), findsOneWidget);
    },
  );
}
