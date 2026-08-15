import 'dart:async';

import 'package:flutter/material.dart';
import 'package:logging/logging.dart';

import 'package:samapoche/models/dto.dart';
import 'package:samapoche/models/models.dart';
import 'package:samapoche/services/api_client.dart';
import 'package:samapoche/services/cache.dart';
import 'package:samapoche/services/observability.dart';
import 'package:samapoche/services/token_storage.dart';
import 'package:samapoche/utils/format.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppState extends ChangeNotifier {
  final Api api;
  final CacheStore cache;
  final TokenStorage tokenStorage;
  final Logger _log = buildLogger('AppState');

  AppState({
    required this.api,
    required this.cache,
    required this.tokenStorage,
  });

  SharedPreferences? _prefs;
  bool _loaded = false;
  bool _syncing = false;

  UserProfile? user;
  List<Txn> transactions = [];
  bool darkMode = false;
  int budget = 150000;
  int savingsGoal = 300000;
  bool notifPush = true;
  bool notifFactures = true;
  bool notifConseils = true;
  bool ecoData = false;
  bool budgetAuto = true;

  List<AppNotification> notifications = [];
  final List<ChatMessage> chat = [];

  Map<String, int> _categoryIds = {};
  int? _alimentationBudgetId;
  String? _lastSyncError;
  bool _sessionExpired = false;
  int _pendingCount = 0;

  bool get loaded => _loaded;
  bool get syncing => _syncing;
  bool get hasPendingSync => _pendingCount > 0;
  bool get sessionExpired => _sessionExpired;
  String? get lastSyncError => _lastSyncError;

  Map<int, String> get _categoryNames => {
    for (final e in _categoryIds.entries) e.value: e.key,
  };

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    darkMode = _prefs!.getBool('samapoche_dark') ?? false;
    budget = _prefs!.getInt('samapoche_budget') ?? 150000;
    savingsGoal = _prefs!.getInt('samapoche_goal') ?? 300000;
    notifPush = _prefs!.getBool('samapoche_notif_push') ?? true;
    notifFactures = _prefs!.getBool('samapoche_notif_factures') ?? true;
    notifConseils = _prefs!.getBool('samapoche_notif_conseils') ?? true;
    ecoData = _prefs!.getBool('samapoche_eco') ?? false;
    budgetAuto = _prefs!.getBool('samapoche_budget_auto') ?? true;

    final stored = await tokenStorage.read() ?? _migrateLegacyToken();
    if (stored != null && stored.isNotEmpty) {
      api.token = stored;
      await refresh();
    }

    _loaded = true;
    notifyListeners();
  }

  /// Migration depuis l'ancien stockage SharedPreferences (v1).
  String? _migrateLegacyToken() {
    final legacy = _prefs!.getString('samapoche_token');
    if (legacy == null || legacy.isEmpty) return null;
    unawaited(tokenStorage.write(legacy));
    unawaited(_prefs!.remove('samapoche_token'));
    return legacy;
  }

  Future<void> refresh() => _sync(silent: false);

  Future<void> _sync({required bool silent}) async {
    if (_syncing) return;
    if (api.token == null) return;
    _syncing = true;
    _lastSyncError = null;
    if (!silent) notifyListeners();
    try {
      final me = await api.me();
      user = UserProfile.fromDto(me);
      await cache.storeUser(user!.toJson());

      await _loadCategories();
      await _flushPending();
      await _syncTransactions();
      await _syncBudgets();
      await _syncNotifications();
      _sessionExpired = false;
    } on ApiException catch (e) {
      _log.warning('Sync échoué: ${e.message}');
      if (e.statusCode == 401) {
        _lastSyncError = e.message;
        await logout(silent: true);
        _sessionExpired = true;
      } else {
        _lastSyncError = e.message;
        _loadCachedData();
      }
    } on Exception catch (e, st) {
      _log.severe('Sync inattendu', e, st);
      Observability.capture(e, st);
      _lastSyncError = 'Erreur inattendue. Réessayez.';
      _loadCachedData();
    } finally {
      _syncing = false;
      notifyListeners();
    }
  }

  Future<void> _loadCategories() async {
    final list = await api.categories();
    _categoryIds = {for (final c in list) c.name: c.id};
    await cache.storeCategories([for (final c in list) c.toJson()]);
  }

  Future<void> _syncTransactions() async {
    final list = await api.transactions();
    transactions = [for (final d in list) Txn.fromDto(d, _categoryNames)]
      ..sort((a, b) => b.date.compareTo(a.date));
    await cache.storeTransactions([for (final d in list) d.toJson()]);
  }

  Future<void> _syncBudgets() async {
    final list = await api.budgets();
    final alimentation = list.where((b) => b.categoryName == 'Alimentation');
    if (alimentation.isNotEmpty) {
      final b = alimentation.first;
      _alimentationBudgetId = b.id;
      budget = b.amount.round();
      await _prefs!.setInt('samapoche_budget', budget);
    }
    await cache.storeBudgets([for (final b in list) b.toJson()]);
  }

  Future<void> _syncNotifications() async {
    final list = await api.notifications();
    final now = DateTime.now();
    notifications = [
      for (final n in list)
        AppNotification.fromDto(
          n,
          time: _notifTime(n.createdAt.toLocal(), now),
          group: _notifGroup(n.createdAt.toLocal(), now),
        ),
    ];
    await cache.storeNotifications([for (final n in list) n.toJson()]);
  }

  /// Rejoue les écritures différées (créées hors-ligne).
  Future<void> _flushPending() async {
    final pending = cache.pendingTransactions;
    if (pending == null || pending.isEmpty) return;
    final remaining = <Map<String, dynamic>>[];
    for (final raw in pending) {
      final payload = raw as Map<String, dynamic>;
      try {
        await api.createTransaction(
          amount: (payload['amount'] as num).toDouble(),
          type: payload['type'] == 'income'
              ? TransactionType.income
              : TransactionType.expense,
          categoryId: (payload['category_id'] as num).toInt(),
          description: payload['description'] as String?,
          date: payload['transaction_date'] != null
              ? DateTime.parse(payload['transaction_date'] as String)
              : null,
        );
      } on ApiException catch (e) {
        _log.warning('Rejeu d\'une écriture différée échoué: ${e.message}');
        remaining.add(payload);
      }
    }
    _pendingCount = remaining.length;
    if (remaining.isEmpty) {
      await cache.clearPendingTransactions();
    } else {
      await cache.storePendingTransactions(remaining);
    }
  }

  /// Hors-ligne : dernière image connue du serveur, sinon rien.
  void _loadCachedData() {
    if (_categoryIds.isEmpty) {
      final c = cache.categories;
      if (c != null) {
        final cats = [
          for (final e in c)
            CategoryDto.fromJson(Map<String, dynamic>.from(e as Map)),
        ];
        _categoryIds = {for (final cat in cats) cat.name: cat.id};
      }
    }
    if (user == null) {
      final u = cache.user;
      if (u != null) user = UserProfile.fromJson(u.cast<String, dynamic>());
    }
    if (transactions.isEmpty) {
      final t = cache.transactions;
      if (t != null) {
        transactions = [
          for (final e in t)
            Txn.fromDto(
              TransactionDto.fromJson(Map<String, dynamic>.from(e as Map)),
              _categoryNames,
            ),
        ]..sort((a, b) => b.date.compareTo(a.date));
      }
    }
  }

  // ─── Auth ────────────────────────────────────────────────
  Future<String?> signup(UserProfile p, String password) async {
    try {
      final token = await api.register(
        email: p.email,
        password: password,
        fullName: p.fullName,
      );
      api.token = token.accessToken;
      await tokenStorage.write(token.accessToken);
      await _sync(silent: true);
      return null;
    } on ApiException catch (e) {
      return e.message;
    }
  }

  Future<String?> login(String email, String password) async {
    try {
      final token = await api.login(email: email, password: password);
      api.token = token.accessToken;
      await tokenStorage.write(token.accessToken);
      await _sync(silent: true);
      return null;
    } on ApiException catch (e) {
      return e.message;
    }
  }

  Future<void> logout({bool silent = false}) async {
    user = null;
    transactions = [];
    notifications = [];
    chat.clear();
    api.token = null;
    _alimentationBudgetId = null;
    _sessionExpired = false;
    _lastSyncError = null;
    await tokenStorage.delete();
    await cache.clearUserData();
    if (!silent) notifyListeners();
  }

  Future<void> saveProfile(UserProfile p) async {
    user = p;
    await cache.storeUser(p.toJson());
    notifyListeners();
  }

  // ─── Transactions ────────────────────────────────────────
  /// Écriture offline-first : l'app est optimiste, le serveur suit.
  /// Si le serveur est injoignable, l'écriture est différée et rejouée
  /// automatiquement à la prochaine synchronisation.
  Future<String?> addTxn(Txn t) async {
    final catId = _categoryIds[t.category];
    if (catId == null) return 'Catégorie inconnue du serveur.';
    final payload = {
      'amount': t.amount.toDouble(),
      'type': t.type.name,
      'category_id': catId,
      if (t.description.isNotEmpty) 'description': t.description,
      'transaction_date': t.date.toUtc().toIso8601String(),
    };
    transactions.insert(0, t);
    await _cacheTxns();
    notifyListeners();
    try {
      final created = await api.createTransaction(
        amount: t.amount.toDouble(),
        type: t.type == TxnType.income
            ? TransactionType.income
            : TransactionType.expense,
        categoryId: catId,
        description: t.description.isNotEmpty ? t.description : null,
        date: t.date,
      );
      final i = transactions.indexWhere((x) => x.id == t.id);
      if (i >= 0) transactions[i] = Txn.fromDto(created, _categoryNames);
      await _cacheTxns();
      return null;
    } on ApiException catch (e) {
      _log.info('Création différée (hors-ligne): ${e.message}');
      await cache.storePendingTransactions([
        ...(cache.pendingTransactions ?? <dynamic>[])
            .cast<Map<String, dynamic>>(),
        payload,
      ]);
      _pendingCount += 1;
      notifyListeners();
      return null;
    }
  }

  Future<String?> updateTxn(Txn t) async {
    if (api.token == null) return 'Session expirée. Reconnectez-vous.';
    final id = int.tryParse(t.id);
    if (id == null) return 'Transaction introuvable.';
    final catId = _categoryIds[t.category];
    if (catId == null) return 'Catégorie inconnue du serveur.';
    try {
      await api.updateTransaction(
        id,
        amount: t.amount.toDouble(),
        categoryId: catId,
        description: t.description.isNotEmpty ? t.description : null,
      );
      final i = transactions.indexWhere((x) => x.id == t.id);
      if (i >= 0) transactions[i] = t;
      await _cacheTxns();
      notifyListeners();
      return null;
    } on ApiException catch (e) {
      return e.message;
    }
  }

  Future<void> _cacheTxns() async {
    await cache.storeTransactions([
      for (final t in transactions)
        {
          'id': int.tryParse(t.id) ?? 0,
          'user_id': user?.id ?? 0,
          'amount': t.amount.toDouble(),
          'type': t.type.name,
          'description': t.description.isEmpty ? null : t.description,
          'category_id': _categoryIds[t.category] ?? 0,
          'transaction_date': t.date.toUtc().toIso8601String(),
          'created_at': t.date.toUtc().toIso8601String(),
        },
    ]);
  }

  // ─── Dashboard computed ──────────────────────────────────
  int get balance => transactions.fold(0, (s, t) => s + t.signed);

  List<Txn> get monthTxns {
    final now = DateTime.now();
    return transactions
        .where((t) => t.date.year == now.year && t.date.month == now.month)
        .toList();
  }

  int get monthIncome => monthTxns
      .where((t) => t.type == TxnType.income)
      .fold(0, (s, t) => s + t.amount);

  int get monthExpense => monthTxns
      .where((t) => t.type == TxnType.expense)
      .fold(0, (s, t) => s + t.amount);

  int get budgetSpent => transactions
      .where(
        (t) =>
            t.category == 'Alimentation' &&
            t.type == TxnType.expense &&
            _sameMonth(t.date),
      )
      .fold(0, (s, t) => s + t.amount);

  int get budgetRemaining => budget - budgetSpent;

  double get budgetPct =>
      budget == 0 ? 0 : (budgetSpent / budget).clamp(0, 1.0);

  int get daysLeftInMonth {
    final now = DateTime.now();
    final last = DateTime(now.year, now.month + 1, 0).day;
    return last - now.day;
  }

  int get dailyAvg =>
      daysLeftInMonth == 0 ? 0 : (budgetRemaining / daysLeftInMonth).round();

  bool _sameMonth(DateTime d) {
    final now = DateTime.now();
    return d.year == now.year && d.month == now.month;
  }

  List<(String, int, Color)> get donutData {
    final byCat = <String, int>{};
    for (final t in transactions.where(
      (t) => t.type == TxnType.expense && _sameMonth(t.date),
    )) {
      byCat[t.category] = (byCat[t.category] ?? 0) + t.amount;
    }
    if (byCat.isEmpty) return [];
    final total = byCat.values.fold(0, (s, v) => s + v);
    final list = byCat.entries.map((e) {
      final c = Categories.byName(e.key);
      return (e.key, (e.value / total * 100).round(), c.fg);
    }).toList()..sort((a, b) => b.$2.compareTo(a.$2));
    return list;
  }

  // ─── Notifications ──────────────────────────────────────
  Future<void> markAllRead() async {
    notifications = [for (final n in notifications) n.copyWith(read: true)];
    notifyListeners();
    try {
      await api.markAllNotificationsRead();
    } on ApiException catch (e) {
      _log.warning('markAllRead: ${e.message}');
    }
  }

  Future<void> markRead(AppNotification n) async {
    notifications = [
      for (final x in notifications) x.id == n.id ? x.copyWith(read: true) : x,
    ];
    notifyListeners();
    if (n.id != null) {
      try {
        await api.markNotificationRead(n.id!);
      } on ApiException catch (e) {
        _log.warning('markRead: ${e.message}');
      }
    }
  }

  // ─── Chat ────────────────────────────────────────────────
  Future<String> chatReply(String message) async {
    try {
      final reply = await api.chat(message);
      return reply.reply;
    } on ApiException catch (e) {
      return 'Je n\'ai pas pu répondre pour le moment. ${e.message}';
    }
  }

  void clearChat() {
    chat
      ..clear()
      ..add(
        ChatMessage(
          text: 'Conversation effacée. Je suis là pour vous aider !',
          fromUser: false,
          time: DateTime.now(),
        ),
      );
    notifyListeners();
  }

  // ─── Budget ──────────────────────────────────────────────
  Future<String?> setBudget(int v) async {
    final prev = budget;
    budget = v;
    await _prefs!.setInt('samapoche_budget', v);
    notifyListeners();
    final catId = _categoryIds['Alimentation'] ?? _categoryIds['Autres'];
    if (catId == null) return null;
    final now = DateTime.now();
    try {
      if (_alimentationBudgetId != null) {
        await api.updateBudget(_alimentationBudgetId!, amount: v.toDouble());
      } else {
        final created = await api.createBudget(
          categoryId: catId,
          amount: v.toDouble(),
          month: now.month,
          year: now.year,
        );
        _alimentationBudgetId = created.id;
      }
      return null;
    } on ApiException catch (e) {
      budget = prev;
      await _prefs!.setInt('samapoche_budget', prev);
      notifyListeners();
      return e.message;
    }
  }

  // ─── Settings ────────────────────────────────────────────
  Future<void> setDarkMode({required bool value}) async {
    darkMode = value;
    await _prefs!.setBool('samapoche_dark', value);
    notifyListeners();
  }

  Future<void> setGoal(int v) async {
    savingsGoal = v;
    await _prefs!.setInt('samapoche_goal', v);
    notifyListeners();
  }

  Future<void> setPref(String key, {required bool value}) async {
    final v = value;
    switch (key) {
      case 'push':
        notifPush = v;
        await _prefs!.setBool('samapoche_notif_push', v);
        break;
      case 'factures':
        notifFactures = v;
        await _prefs!.setBool('samapoche_notif_factures', v);
        break;
      case 'conseils':
        notifConseils = v;
        await _prefs!.setBool('samapoche_notif_conseils', v);
        break;
      case 'eco':
        ecoData = v;
        await _prefs!.setBool('samapoche_eco', v);
        break;
      case 'auto':
        budgetAuto = v;
        await _prefs!.setBool('samapoche_budget_auto', v);
        break;
    }
    notifyListeners();
  }

  String _notifTime(DateTime dt, DateTime now) {
    if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    }
    return formatDateListe(dt);
  }

  String _notifGroup(DateTime dt, DateTime now) {
    final diff = now.difference(dt).inDays;
    if (diff <= 1) return "Aujourd'hui";
    if (diff <= 7) return 'Cette semaine';
    return '${monthsFr[dt.month - 1]} ${dt.year}';
  }
}

const monthsFr = [
  'Janvier',
  'Février',
  'Mars',
  'Avril',
  'Mai',
  'Juin',
  'Juillet',
  'Août',
  'Septembre',
  'Octobre',
  'Novembre',
  'Décembre',
];
