import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:samapoche/main.dart' as app;
import 'package:shared_preferences/shared_preferences.dart';

/// Parcours E2E complet contre le backend réel (voir `API_BASE_URL`).
///
/// Prérequis : backend AFI démarré (localement : http://localhost:8000).
/// Sur émulateur Android, lancer avec :
///   flutter test integration_test -d `device` \
///     --dart-define=API_BASE_URL=http://10.0.2.2:8000
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('E2E : inscription → ajout de transaction → liste', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final email = 'e2e.${DateTime.now().millisecondsSinceEpoch}@test.dev';

    await app.runAppWith(
      apiBaseUrl: const String.fromEnvironment(
        'API_BASE_URL',
        defaultValue: 'http://localhost:8000',
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Gérez mieux. Économisez plus.'), findsOneWidget);

    // Inscription
    await tester.tap(find.text('Créer un compte'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).at(0), 'E2E');
    await tester.enterText(find.byType(TextField).at(1), 'Test');
    await tester.enterText(find.byType(TextField).at(2), email);
    await tester.enterText(find.byType(TextField).at(3), '+228 90000000');
    await tester.enterText(find.byType(TextField).at(4), 'Test1234!');
    await tester.enterText(find.byType(TextField).at(5), 'Test1234!');

    await tester.tap(find.textContaining("J'accepte les"));
    await tester.pumpAndSettle();

    await tester.tap(find.text("S'inscrire"));
    await tester.pumpAndSettle(const Duration(seconds: 3));

    // Écran d'accueil (synchronisé avec le serveur)
    expect(find.text('Répartition des dépenses'), findsOneWidget);

    // Ajout d'une transaction
    await tester.tap(find.byTooltip('Nouvelle transaction'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).at(0), '5000');
    await tester.enterText(find.byType(TextField).at(1), 'Test E2E');
    await tester.tap(find.text('Enregistrer'));
    await tester.pumpAndSettle(const Duration(seconds: 3));

    // La transaction apparaît dans l'onglet Transactions
    await tester.tap(find.text('Transactions'));
    await tester.pumpAndSettle(const Duration(seconds: 3));

    expect(find.text('Test E2E'), findsOneWidget);

    // Retour à l'accueil via la barre du bas
    await tester.tap(find.text('Accueil'));
    await tester.pumpAndSettle();
    expect(find.text('Répartition des dépenses'), findsOneWidget);
  });
}
