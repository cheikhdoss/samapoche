import 'package:flutter_test/flutter_test.dart';
import 'package:samapoche/data/repositories/auth_repository.dart';
import 'package:samapoche/data/repositories/budgets_repository.dart';
import 'package:samapoche/data/repositories/categories_repository.dart';
import 'package:samapoche/data/repositories/chat_repository.dart';
import 'package:samapoche/data/repositories/notifications_repository.dart';
import 'package:samapoche/data/repositories/transactions_repository.dart';
import 'package:samapoche/domain/models.dart';
import 'package:samapoche/domain/usecases.dart';
import 'package:samapoche/services/api_client.dart';
import 'package:samapoche/services/cache.dart';
import 'package:samapoche/services/token_storage.dart';
import 'package:samapoche/testing/fake_backend.dart';

/// Les tests de la couche données ciblent directement les repositories et le
/// [SyncUseCase] (sans passer par AppState) : la DI est utilisable telle
/// quelle, comme dans l'application réelle.
void main() {
  late TestBackend backend;
  late MemoryCache cache;
  late Api api;
  late AuthRepository auth;
  late CategoriesRepository categories;
  late TransactionsRepository txns;
  late BudgetsRepository budgets;
  late NotificationsRepository notifications;
  late ChatRepository chat;
  late SyncUseCase sync;

  setUp(() {
    backend = TestBackend(TestControls());
    cache = MemoryCache();
    api = Api(baseUrl: 'http://test.local', client: backend.client);
    auth = AuthRepository(
      api: api,
      cache: cache,
      tokenStorage: TokenStorage(storage: FakeSecureStorage()),
    );
    categories = CategoriesRepository(api: api, cache: cache);
    txns = TransactionsRepository(api: api, cache: cache);
    budgets = BudgetsRepository(api: api, cache: cache);
    notifications = NotificationsRepository(api: api, cache: cache);
    chat = ChatRepository(api: api);
    sync = SyncUseCase(
      auth: auth,
      categories: categories,
      transactions: txns,
      budgets: budgets,
      notifications: notifications,
    );
  });

  group('SyncUseCase', () {
    test(
      'run → profil, catégories, transactions, budgets, notifications',
      () async {
        await auth.login(email: 'user@test.dev', password: 'secret');

        final result = await sync.run();

        expect(result.user.fullName, 'Test User');
        expect(result.categoryNames, containsPair(1, 'Alimentation'));
        expect(result.transactions, hasLength(2));
        expect(result.transactions.first.name, 'Riz bag');
        expect(result.budgets, isNotEmpty);
        expect(result.notifications, hasLength(1));
        expect(result.pendingRemaining, 0);
      },
    );

    test(
      'écriture différée rejouée → pendingRemaining 0 et créée côté serveur',
      () async {
        await auth.login(email: 'user@test.dev', password: 'secret');
        final before = backend.transactions.length;
        await cache.storePendingTransactions([
          {
            'amount': 5000.0,
            'type': 'expense',
            'category_id': 1,
            'description': 'Courses',
            'transaction_date': DateTime.now().toUtc().toIso8601String(),
          },
        ]);

        final result = await sync.run();

        expect(result.pendingRemaining, 0);
        expect(cache.pendingTransactions, isNull);
        expect(backend.transactions.length, before + 1);
      },
    );

    test(
      '401 → ApiException propagée (l\'état décide de la session)',
      () async {
        await auth.login(email: 'user@test.dev', password: 'secret');
        backend.controls.expiredToken = true;

        expect(() => sync.run(), throwsA(isA<ApiException>()));
      },
    );
  });

  group('TransactionsRepository', () {
    test('createOfflineFirst hors-ligne → différée dans le cache', () async {
      await auth.login(email: 'user@test.dev', password: 'secret');
      backend.controls.networkDown = true;
      final local = Txn(
        id: 'local-1',
        name: 'Courses',
        category: 'Alimentation',
        type: TxnType.expense,
        amount: 5000,
        description: 'Courses',
        payment: 'Espèces',
        date: DateTime.now(),
      );

      final outcome = await txns.createOfflineFirst(
        local: local,
        categoryId: 1,
        categoryNames: const {1: 'Alimentation'},
      );

      expect(outcome, isA<CreateTxnDeferred>());
      expect((outcome as CreateTxnDeferred).pendingCount, 1);
      expect(txns.hasPending, isTrue);
    });

    test('createOfflineFirst en ligne → id serveur réel', () async {
      await auth.login(email: 'user@test.dev', password: 'secret');
      final local = Txn(
        id: 'local-1',
        name: 'Courses',
        category: 'Alimentation',
        type: TxnType.expense,
        amount: 5000,
        description: 'Courses',
        payment: 'Espèces',
        date: DateTime.now(),
      );

      final outcome = await txns.createOfflineFirst(
        local: local,
        categoryId: 1,
        categoryNames: const {1: 'Alimentation'},
      );

      expect(outcome, isA<CreateTxnSuccess>());
      expect((outcome as CreateTxnSuccess).txn.id, '10');
      expect(txns.hasPending, isFalse);
    });
  });

  group('AuthRepository', () {
    test('login → token exposé (mémoire) et session', () async {
      final err = await auth.login(email: 'user@test.dev', password: 'secret');

      expect(err, isNull);
      expect(auth.hasToken, isTrue);
      expect(auth.token, 'tok-test');
    });

    test('logout → token effacé et données locales purgées', () async {
      await auth.login(email: 'user@test.dev', password: 'secret');
      await auth.me();
      expect(cache.user, isNotNull);

      await auth.logout();

      expect(auth.hasToken, isFalse);
      expect(cache.user, isNull);
      expect(cache.transactions, isNull);
    });

    test('conversion DTO → domaine à la frontière (me)', () async {
      await auth.login(email: 'user@test.dev', password: 'secret');

      final user = await auth.me();

      expect(user.fullName, 'Test User');
      expect(user.email, 'user@test.dev');
    });
  });

  group('ChatRepository', () {
    test('réponse brute de l\'assistant', () async {
      await auth.login(email: 'user@test.dev', password: 'secret');

      expect(await chat.reply('Salut'), 'Bonjour ! Voici un conseil.');
    });
  });

  group('NotificationsRepository', () {
    test('marquer tout lu → appelé sans erreur', () async {
      await auth.login(email: 'user@test.dev', password: 'secret');

      await notifications.fetch();
      await notifications.markAllRead();

      expect(notifications, isNotNull);
    });

    test('marquer une notification lue', () async {
      await auth.login(email: 'user@test.dev', password: 'secret');

      await notifications.fetch();

      await notifications.markRead(1);
    });
  });
}
