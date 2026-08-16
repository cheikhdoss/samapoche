import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:samapoche/env.dart';
import 'package:samapoche/screens/add_transaction_screen.dart';
import 'package:samapoche/screens/assistant_screen.dart';
import 'package:samapoche/screens/notifications_screen.dart';
import 'package:samapoche/screens/profile_screen.dart';
import 'package:samapoche/screens/transactions_screen.dart';
import 'package:samapoche/state/app_state.dart';
import 'package:samapoche/testing/fake_backend.dart';
import 'package:samapoche/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Tests d'écrans : rendu réel (Provider + thème), interactions et flux
/// bout en bout du réseau (faux backend injecté).
void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
  });

  Future<TestContext> loggedIn() async {
    final ctx = await createTestContext();
    await ctx.state.init();
    await ctx.state.login('user@test.dev', 'secret');
    return ctx;
  }

  Widget host(Widget child, AppState state) => ChangeNotifierProvider.value(
    value: state,
    child: Provider<AppConfig>.value(
      value: const AppConfig(
        flavor: Flavor.dev,
        apiBaseUrl: 'http://test.local',
      ),
      child: MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(body: child),
      ),
    ),
  );

  testWidgets('Transactions : rendu, recherche et filtre par type', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 2200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final ctx = await loggedIn();
    await tester.pumpWidget(host(const TransactionsScreen(), ctx.state));
    await tester.pumpAndSettle();

    expect(find.text('Transactions'), findsOneWidget);
    expect(find.text('Riz bag'), findsOneWidget);
    expect(find.text('Salaire'), findsOneWidget);

    await tester.enterText(
      find.byType(TextField).first,
      'Riz',
    );
    await tester.pumpAndSettle();

    expect(find.text('Riz bag'), findsOneWidget);
    expect(find.text('Salaire'), findsNothing);
  });

  testWidgets('Notifications : filtres, tout marquer lu, lire une notif', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 2200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final ctx = await loggedIn();
    await tester.pumpWidget(host(const NotificationsScreen(), ctx.state));
    await tester.pumpAndSettle();

    expect(find.text('Aucune notification'), findsNothing);

    await tester.tap(find.text('Non lues'));
    await tester.pumpAndSettle();
    expect(find.text('Aucune notification'), findsNothing);

    await tester.tap(find.text('Tout marquer comme lu'));
    await tester.pumpAndSettle();
    // Laisse le toast (4 s) disparaître avant de toucher aux chips.
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();

    expect(ctx.state.notifications.every((n) => n.read), isTrue);

    await tester.tap(find.text('Lues'));
    await tester.pumpAndSettle();
    expect(find.text('Aucune notification'), findsNothing);

    await tester.tap(find.text('Toutes'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Budget Alimentation'));
    await tester.pumpAndSettle();
  });

  testWidgets('Assistant : envoyer un message → réponse du serveur', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 2200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final ctx = await loggedIn();
    await tester.pumpWidget(host(const AssistantScreen(), ctx.state));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byType(TextField),
      'Quelles sont mes dépenses ?',
    );
    await tester.tap(find.bySemanticsLabel('Envoyer le message'));
    await tester.pumpAndSettle();

    expect(find.text('Quelles sont mes dépenses ?'), findsOneWidget);
    expect(find.text('Bonjour ! Voici un conseil.'), findsOneWidget);
  });

  testWidgets('Profil : diagnostic d\'environnement (flavor dev)', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 2200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final ctx = await loggedIn();
    await tester.pumpWidget(host(const ProfileScreen(), ctx.state));
    await tester.pumpAndSettle();

    expect(find.text('Environnement'), findsOneWidget);
    expect(find.text('Développement'), findsOneWidget);
  });

  testWidgets('Ajout : formulaire complet → transaction créée côté serveur', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final ctx = await loggedIn();
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => const AddTransactionScreen(),
        ),
        GoRoute(path: '/home', builder: (_, _) => const Scaffold()),
      ],
    );
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: ctx.state,
        child: Provider<AppConfig>.value(
          value: const AppConfig(
            flavor: Flavor.dev,
            apiBaseUrl: 'http://test.local',
          ),
          child: MaterialApp.router(
            theme: AppTheme.light(),
            routerConfig: router,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).at(0), '5000');
    await tester.tap(find.text('Alimentation'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextField).at(1),
      'Courses du marché',
    );
    await tester.tap(find.text('Enregistrer'));
    await tester.pumpAndSettle();

    expect(ctx.state.transactions.first.description, 'Courses du marché');
    expect(ctx.state.transactions.first.id, '10');
    expect(ctx.state.hasPendingSync, isFalse);

    // Laisse le toast (4 s) se terminer avant la fin du test.
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
  });
}
