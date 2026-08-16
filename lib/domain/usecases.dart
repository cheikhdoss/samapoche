import 'package:samapoche/data/repositories/auth_repository.dart';
import 'package:samapoche/data/repositories/budgets_repository.dart';
import 'package:samapoche/data/repositories/categories_repository.dart';
import 'package:samapoche/data/repositories/notifications_repository.dart';
import 'package:samapoche/data/repositories/transactions_repository.dart';
import 'package:samapoche/domain/models.dart';
import 'package:samapoche/models/dto.dart';

/// Résultat d'une synchronisation complète.
class SyncResult {
  final UserProfile user;
  final Map<int, String> categoryNames;
  final List<Txn> transactions;
  final List<BudgetStatusDto> budgets;
  final List<NotificationDto> notifications;
  final int pendingRemaining;

  const SyncResult({
    required this.user,
    required this.categoryNames,
    required this.transactions,
    required this.budgets,
    required this.notifications,
    required this.pendingRemaining,
  });
}

/// Orchestration de la synchronisation initiale : profil, référentiel des
/// catégories, rejeu des écritures hors-ligne, transactions, budgets et
/// notifications — dans cet ordre (une écriture différée doit apparaître
/// dans l'état frais qui suit).
///
/// Un seul use case dédié : les autres opérations du domaine (écrire une
/// transaction, marquer une notification...) ne touchent qu'un agrégat et
/// vivent directement dans leur repository.
class SyncUseCase {
  final AuthRepository auth;
  final CategoriesRepository categories;
  final TransactionsRepository transactions;
  final BudgetsRepository budgets;
  final NotificationsRepository notifications;

  SyncUseCase({
    required this.auth,
    required this.categories,
    required this.transactions,
    required this.budgets,
    required this.notifications,
  });

  Future<SyncResult> run() async {
    final user = await auth.me();
    final categoryNames = await categories.names();
    final pendingRemaining = await transactions.replayPending(
      categoryNames: categoryNames,
    );
    final transactionList = await transactions.fetch(
      categoryNames: categoryNames,
    );
    final budgetList = await budgets.fetch();
    final notificationList = await notifications.fetch();
    return SyncResult(
      user: user,
      categoryNames: categoryNames,
      transactions: transactionList,
      budgets: budgetList,
      notifications: notificationList,
      pendingRemaining: pendingRemaining,
    );
  }
}
