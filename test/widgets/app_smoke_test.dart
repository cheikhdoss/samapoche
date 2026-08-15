import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:samapoche/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers.dart';

void main() {
  late TestContext ctx;

  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
  });

  Future<void> pumpApp(WidgetTester tester) async {
    ctx = await createTestContext();
    await tester.pumpWidget(SamaPocheApp(state: ctx.state));
    await tester.pumpAndSettle();
  }

  testWidgets('démarre sur l\'écran Welcome (l10n FR)', (tester) async {
    await pumpApp(tester);

    expect(find.text('SamaPoche'), findsOneWidget);
    expect(find.text("S'identifier"), findsOneWidget);
    expect(find.text('Créer un compte'), findsOneWidget);
    expect(find.text('Gérez mieux. Économisez plus.'), findsOneWidget);
  });

  testWidgets('Welcome → Signup → Retour', (tester) async {
    await pumpApp(tester);

    await tester.tap(find.text('Créer un compte'));
    await tester.pumpAndSettle();
    expect(find.text('Rejoignez SamaPoche en un instant'), findsOneWidget);

    await tester.tap(find.text('Retour'));
    await tester.pumpAndSettle();
    expect(find.text('Gérez mieux. Économisez plus.'), findsOneWidget);
  });

  testWidgets('login complet → écran d\'accueil avec données serveur', (
    tester,
  ) async {
    await pumpApp(tester);

    await tester.tap(find.text("S'identifier"));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).at(0), 'user@test.dev');
    await tester.enterText(find.byType(TextField).at(1), 'secret');
    await tester.tap(find.text('Continuer'));
    await tester.pumpAndSettle();

    expect(find.text('Répartition des dépenses'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Riz bag'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Riz bag'), findsOneWidget);
    expect(find.text('Salaire'), findsWidgets);

    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
  });
}
