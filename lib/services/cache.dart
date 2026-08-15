import 'package:hive/hive.dart';

/// Contrat du stockage local hors-ligne, indexé par ressource.
///
/// Les valeurs sont les payloads bruts du serveur (`List<Map<String, dynamic>>`)
/// typés à la frontière via les DTO générés (json_serializable).
abstract class CacheStore {
  Future<void> init();

  Future<void> storeCategories(List<Map<String, dynamic>> value);
  List<dynamic>? get categories;

  Future<void> storeTransactions(List<Map<String, dynamic>> value);
  List<dynamic>? get transactions;

  Future<void> storeBudgets(List<Map<String, dynamic>> value);
  List<dynamic>? get budgets;

  Future<void> storeNotifications(List<Map<String, dynamic>> value);
  List<dynamic>? get notifications;

  Future<void> storeUser(Map<String, dynamic> value);
  Map<dynamic, dynamic>? get user;

  /// Écritures de transactions différées (créations hors-ligne).
  Future<void> storePendingTransactions(List<Map<String, dynamic>> value);
  List<dynamic>? get pendingTransactions;

  Future<void> clearPendingTransactions();
  Future<void> clearUserData();
}

/// Implémentation Hive (sur disque, app réelle).
class HiveCache implements CacheStore {
  static const _boxName = 'samapoche_cache';
  static const _kCategories = 'categories';
  static const _kTransactions = 'transactions';
  static const _kBudgets = 'budgets';
  static const _kNotifications = 'notifications';
  static const _kPendingTxns = 'pending_transactions';
  static const _kUser = 'user';

  late final Box<dynamic> _box;

  @override
  Future<void> init() async {
    _box = await Hive.openBox<dynamic>(_boxName);
  }

  @override
  Future<void> storeCategories(List<Map<String, dynamic>> value) =>
      _box.put(_kCategories, value);

  @override
  List<dynamic>? get categories => _box.get(_kCategories) as List<dynamic>?;

  @override
  Future<void> storeTransactions(List<Map<String, dynamic>> value) =>
      _box.put(_kTransactions, value);

  @override
  List<dynamic>? get transactions => _box.get(_kTransactions) as List<dynamic>?;

  @override
  Future<void> storeBudgets(List<Map<String, dynamic>> value) =>
      _box.put(_kBudgets, value);

  @override
  List<dynamic>? get budgets => _box.get(_kBudgets) as List<dynamic>?;

  @override
  Future<void> storeNotifications(List<Map<String, dynamic>> value) =>
      _box.put(_kNotifications, value);

  @override
  List<dynamic>? get notifications =>
      _box.get(_kNotifications) as List<dynamic>?;

  @override
  Future<void> storeUser(Map<String, dynamic> value) => _box.put(_kUser, value);

  @override
  Map<dynamic, dynamic>? get user => _box.get(_kUser) as Map<dynamic, dynamic>?;

  @override
  Future<void> storePendingTransactions(List<Map<String, dynamic>> value) =>
      _box.put(_kPendingTxns, value);

  @override
  List<dynamic>? get pendingTransactions =>
      _box.get(_kPendingTxns) as List<dynamic>?;

  @override
  Future<void> clearPendingTransactions() => _box.delete(_kPendingTxns);

  @override
  Future<void> clearUserData() async {
    await _box.delete(_kUser);
    await _box.delete(_kTransactions);
    await _box.delete(_kCategories);
    await _box.delete(_kBudgets);
    await _box.delete(_kNotifications);
  }
}

/// Implémentation en mémoire (tests unitaires et de widgets).
class MemoryCache implements CacheStore {
  final Map<String, dynamic> _data = {};

  @override
  Future<void> init() async {}

  @override
  Future<void> storeCategories(List<Map<String, dynamic>> value) async =>
      _data['categories'] = value;

  @override
  List<dynamic>? get categories => _data['categories'] as List<dynamic>?;

  @override
  Future<void> storeTransactions(List<Map<String, dynamic>> value) async =>
      _data['transactions'] = value;

  @override
  List<dynamic>? get transactions => _data['transactions'] as List<dynamic>?;

  @override
  Future<void> storeBudgets(List<Map<String, dynamic>> value) async =>
      _data['budgets'] = value;

  @override
  List<dynamic>? get budgets => _data['budgets'] as List<dynamic>?;

  @override
  Future<void> storeNotifications(List<Map<String, dynamic>> value) async =>
      _data['notifications'] = value;

  @override
  List<dynamic>? get notifications => _data['notifications'] as List<dynamic>?;

  @override
  Future<void> storeUser(Map<String, dynamic> value) async =>
      _data['user'] = value;

  @override
  Map<dynamic, dynamic>? get user => _data['user'] as Map<dynamic, dynamic>?;

  @override
  Future<void> storePendingTransactions(
    List<Map<String, dynamic>> value,
  ) async => _data['pending_transactions'] = value;

  @override
  List<dynamic>? get pendingTransactions =>
      _data['pending_transactions'] as List<dynamic>?;

  @override
  Future<void> clearPendingTransactions() async =>
      _data.remove('pending_transactions');

  @override
  Future<void> clearUserData() async {
    _data
      ..remove('user')
      ..remove('transactions')
      ..remove('categories')
      ..remove('budgets')
      ..remove('notifications');
  }
}
