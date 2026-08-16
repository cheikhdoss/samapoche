import 'package:flutter_test/flutter_test.dart';
import 'package:samapoche/domain/models.dart';
import 'package:samapoche/testing/fake_backend.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
  });

  Txn txn(String name, {int amount = 5000, TxnType type = TxnType.expense}) =>
      Txn(
        id: 'local-$name',
        name: name,
        category: 'Autres',
        type: type,
        amount: amount,
        description: name,
        payment: 'Espèces',
        date: DateTime.now().subtract(const Duration(hours: 1)),
      );

  Future<TestContext> freshContext() async {
    final ctx = await createTestContext();
    await ctx.state.init();
    return ctx;
  }

  group('Authentification', () {
    test('login réussi → token, user et données synchronisées', () async {
      final ctx = await freshContext();
      final err = await ctx.state.login('user@test.dev', 'secret');

      expect(err, isNull);
      expect(ctx.state.user, isNotNull);
      expect(ctx.state.user!.fullName, 'Test User');
      expect(ctx.state.auth.token, 'tok-test');
      expect(ctx.state.transactions, hasLength(2));
      expect(ctx.state.notifications, hasLength(1));
      expect(ctx.state.hasPendingSync, isFalse);
    });

    test('login refusé (401) → message FR, aucun user', () async {
      final ctx = await freshContext();
      final err = await ctx.state.login('user@test.dev', 'wrong');

      expect(err, 'Identifiants incorrects');
      expect(ctx.state.user, isNull);
      expect(ctx.state.auth.token, isNull);
    });

    test('réseau indisponible → erreur FR, aucun user', () async {
      final ctx = await freshContext();
      ctx.backend.controls.networkDown = true;

      final err = await ctx.state.login('user@test.dev', 'secret');

      expect(err, isNotNull);
      expect(ctx.state.user, isNull);
    });

    test('logout → token effacé et session fermée', () async {
      final ctx = await freshContext();
      await ctx.state.login('user@test.dev', 'secret');
      expect(ctx.state.user, isNotNull);

      await ctx.state.logout();

      expect(ctx.state.user, isNull);
      expect(ctx.state.auth.token, isNull);
      expect(ctx.state.transactions, isEmpty);
    });
  });

  group('Transactions hors-ligne', () {
    test(
      'ajout hors-ligne → optimiste + file d\'attente, replay au refresh',
      () async {
        final ctx = await freshContext();
        await ctx.state.login('user@test.dev', 'secret');

        ctx.backend.controls.networkDown = true;
        final err = await ctx.state.addTxn(txn('Courses'));
        expect(err, isNull);
        expect(ctx.state.transactions, hasLength(3));
        expect(ctx.state.hasPendingSync, isTrue);

        ctx.backend.controls.networkDown = false;
        await ctx.state.refresh();

        expect(ctx.state.hasPendingSync, isFalse);
        expect(
          ctx.state.transactions.where((t) => t.name == 'Courses'),
          hasLength(1),
        );
      },
    );

    test(
      'ajout en ligne → remplacé par la version serveur (id réel)',
      () async {
        final ctx = await freshContext();
        await ctx.state.login('user@test.dev', 'secret');

        final err = await ctx.state.addTxn(txn('Courses'));

        expect(err, isNull);
        expect(ctx.state.hasPendingSync, isFalse);
        expect(ctx.state.transactions.first.id, '10');
      },
    );
  });

  group('Session et sécurité', () {
    test(
      'token expiré pendant un sync → sessionExpired + déconnexion',
      () async {
        final ctx = await freshContext();
        await ctx.state.login('user@test.dev', 'secret');

        ctx.backend.controls.expiredToken = true;
        await ctx.state.refresh();

        expect(ctx.state.sessionExpired, isTrue);
        expect(ctx.state.user, isNull);
        expect(ctx.state.auth.token, isNull);
      },
    );
  });

  group('Dashboard', () {
    test('solde, budget et dépenses du mois depuis les transactions', () async {
      final ctx = await freshContext();
      await ctx.state.login('user@test.dev', 'secret');

      expect(ctx.state.balance, 147500);
      expect(ctx.state.budgetSpent, 2500);
      expect(ctx.state.budgetRemaining, ctx.state.budget - 2500);
      expect(ctx.state.monthTxns, hasLength(2));
      expect(ctx.state.monthIncome, 150000);
      expect(ctx.state.monthExpense, 2500);
      expect(ctx.state.budgetPct, closeTo(2500 / ctx.state.budget, 0.001));
    });
  });

  group('Chat IA', () {
    test('chatReply → réponse du serveur et message conservé', () async {
      final ctx = await freshContext();
      await ctx.state.login('user@test.dev', 'secret');

      final reply = await ctx.state.chatReply('Salut');

      expect(reply, 'Bonjour ! Voici un conseil.');
    });
  });
}
