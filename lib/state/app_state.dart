import 'dart:async';

import 'package:flutter/material.dart';
import 'package:logging/logging.dart';

import 'package:samapoche/data/repositories/auth_repository.dart';
import 'package:samapoche/data/repositories/budgets_repository.dart';
import 'package:samapoche/data/repositories/categories_repository.dart';
import 'package:samapoche/data/repositories/chat_repository.dart';
import 'package:samapoche/data/repositories/dashboard_repository.dart';
import 'package:samapoche/data/repositories/notifications_repository.dart';
import 'package:samapoche/data/repositories/transactions_repository.dart';
import 'package:samapoche/domain/models.dart';
import 'package:samapoche/domain/usecases.dart';
import 'package:samapoche/models/dto.dart';
import 'package:samapoche/services/api_client.dart';
import 'package:samapoche/services/cache.dart';
import 'package:samapoche/services/observability.dart';
import 'package:samapoche/services/token_storage.dart';
import 'package:samapoche/utils/format.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// État applicatif : conteneur d'état UI + orchestration des données.
///
/// Depuis le refactor « repository / use cases », [AppState] ne parle plus
/// au réseau ni au cache : il délègue aux repositories (frontière
/// DTO ↔ domaine) et au [SyncUseCase] (orchestration multi-agrégats), et ne
/// garde que l'état de présentation et les préférences utilisateur.
class AppState extends ChangeNotifier {
  final AuthRepository auth;
  final CategoriesRepository categoriesRepository;
  final TransactionsRepository transactionsRepository;
  final BudgetsRepository budgetsRepository;
  final NotificationsRepository notificationsRepository;
  final ChatRepository chatRepository;
  final DashboardRepository dashboardRepository;
  final SyncUseCase syncUseCase;
  final Logger _log = buildLogger('AppState');

  AppState({
    required this.auth,
    required this.categoriesRepository,
    required this.transactionsRepository,
    required this.budgetsRepository,
    required this.notificationsRepository,
    required this.chatRepository,
    required this.dashboardRepository,
    required this.syncUseCase,
  });

  /// Assemblage par défaut (app et tests) : câble les repositories sur le
  /// transport HTTP, le cache et le stockage sécurisé du token.
  factory AppState.create({
    required Api api,
    required CacheStore cache,
    required TokenStorage tokenStorage,
  }) {
    final auth = AuthRepository(
      api: api,
      cache: cache,
      tokenStorage: tokenStorage,
    );
    final categories = CategoriesRepository(api: api, cache: cache);
    final transactions = TransactionsRepository(api: api, cache: cache);
    final budgets = BudgetsRepository(api: api, cache: cache);
    final notifications = NotificationsRepository(api: api, cache: cache);
    final chat = ChatRepository(api: api);
    final dashboard = DashboardRepository(api: api);
    return AppState(
      auth: auth,
      categoriesRepository: categories,
      transactionsRepository: transactions,
      budgetsRepository: budgets,
      notificationsRepository: notifications,
      chatRepository: chat,
      dashboardRepository: dashboard,
      syncUseCase: SyncUseCase(
        auth: auth,
        categories: categories,
        transactions: transactions,
        budgets: budgets,
        notifications: notifications,
      ),
    );
  }

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

  Map<String, dynamic>? _serverBalance;
  Map<String, dynamic>? _serverStats;

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

    final stored = await auth.restoreToken() ?? _migrateLegacyToken();
    if (stored != null && stored.isNotEmpty) {
      auth.token = stored;
      await refresh();
    }

    _loaded = true;
    notifyListeners();
  }

  /// Migration depuis l'ancien stockage SharedPreferences (v1).
  String? _migrateLegacyToken() {
    final legacy = _prefs!.getString('samapoche_token');
    if (legacy == null || legacy.isEmpty) return null;
    unawaited(auth.persistToken(legacy));
    unawaited(_prefs!.remove('samapoche_token'));
    return legacy;
  }

  Future<void> refresh() => _sync(silent: false);

  Future<void> _sync({required bool silent}) async {
    if (_syncing) return;
    if (!auth.hasToken) return;
    _syncing = true;
    _lastSyncError = null;
    if (!silent) notifyListeners();
    try {
      final result = await syncUseCase.run();
      user = result.user;
      _categoryIds = {
        for (final e in result.categoryNames.entries) e.value: e.key,
      };
      transactions = result.transactions;
      _applyBudgets(result.budgets);
      notifications = _toAppNotifications(result.notifications);
      _pendingCount = result.pendingRemaining;
      _sessionExpired = false;
      await _fetchServerDashboard();
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

  void _applyBudgets(List<BudgetStatusDto> budgets) {
    final alimentation = budgets.where((b) => b.categoryName == 'Alimentation');
    if (alimentation.isEmpty) return;
    final b = alimentation.first;
    _alimentationBudgetId = b.id;
    budget = b.amount.round();
    // Les préférences ne sont disponibles qu'après `init()` : une
    // synchronisation précoce (tests) ne doit pas planter.
    final prefs = _prefs;
    if (prefs != null) {
      unawaited(prefs.setInt('samapoche_budget', budget));
    }
  }

  List<AppNotification> _toAppNotifications(List<NotificationDto> list) {
    final now = DateTime.now();
    return [
      for (final n in list)
        AppNotification.fromDto(
          n,
          time: _notifTime(n.createdAt.toLocal(), now),
          group: _notifGroup(n.createdAt.toLocal(), now),
        ),
    ];
  }

  /// Solde et stats du serveur (source de vérité) : échec silencieux,
  /// l'app retombe alors sur le calcul local.
  Future<void> _fetchServerDashboard() async {
    try {
      _serverBalance = await dashboardRepository.balance();
    } on Exception catch (e) {
      _log.fine('Dashboard balance indisponible: $e');
      _serverBalance = null;
    }
    try {
      _serverStats = await dashboardRepository.stats();
    } on Exception catch (e) {
      _log.fine('Dashboard stats indisponibles: $e');
      _serverStats = null;
    }
  }

  /// Hors-ligne : dernière image connue du serveur, sinon rien.
  void _loadCachedData() {
    final names = categoriesRepository.cachedNames();
    if (_categoryIds.isEmpty && names != null) {
      _categoryIds = {for (final e in names.entries) e.value: e.key};
    }
    user ??= auth.cachedUser();
    if (transactions.isEmpty && names != null) {
      transactions = transactionsRepository.cached(categoryNames: names);
    }
    _pendingCount = transactionsRepository.pendingCount;
  }

  // ─── Auth ────────────────────────────────────────────────
  Future<String?> signup(UserProfile p, String password) async {
    final error = await auth.signup(
      email: p.email,
      password: password,
      fullName: p.fullName,
    );
    if (error != null) return error;
    await _sync(silent: true);
    return null;
  }

  Future<String?> login(String email, String password) async {
    final error = await auth.login(email: email, password: password);
    if (error != null) return error;
    await _sync(silent: true);
    return null;
  }

  Future<void> logout({bool silent = false}) async {
    user = null;
    transactions = [];
    notifications = [];
    chat.clear();
    _alimentationBudgetId = null;
    _serverBalance = null;
    _serverStats = null;
    _sessionExpired = false;
    _lastSyncError = null;
    await auth.logout();
    if (!silent) notifyListeners();
  }

  Future<void> saveProfile(UserProfile p) async {
    user = p;
    await auth.storeLocalUser(p);
    notifyListeners();
  }

  // ─── Transactions ────────────────────────────────────────
  /// Écriture offline-first : l'app est optimiste, le serveur suit.
  /// Si le serveur est injoignable, l'écriture est différée et rejouée
  /// automatiquement à la prochaine synchronisation.
  Future<String?> addTxn(Txn t) async {
    final catId = _categoryIds[t.category];
    if (catId == null) return 'Catégorie inconnue du serveur.';
    transactions.insert(0, t);
    await _mirror();
    notifyListeners();
    final outcome = await transactionsRepository.createOfflineFirst(
      local: t,
      categoryId: catId,
      categoryNames: _categoryNames,
    );
    switch (outcome) {
      case CreateTxnSuccess(:final txn):
        final i = transactions.indexWhere((x) => x.id == t.id);
        if (i >= 0) transactions[i] = txn;
        _serverBalance = null;
        _serverStats = null;
        await _mirror();
      case CreateTxnDeferred(:final pendingCount):
        _pendingCount = pendingCount;
        notifyListeners();
    }
    return null;
  }

  Future<String?> updateTxn(Txn t) async {
    if (!auth.hasToken) return 'Session expirée. Reconnectez-vous.';
    final id = int.tryParse(t.id);
    if (id == null) return 'Transaction introuvable.';
    final catId = _categoryIds[t.category];
    if (catId == null) return 'Catégorie inconnue du serveur.';
    try {
      final updated = await transactionsRepository.update(
        id,
        amount: t.amount.toDouble(),
        categoryId: catId,
        description: t.description.isNotEmpty ? t.description : null,
        categoryNames: _categoryNames,
      );
      final i = transactions.indexWhere((x) => x.id == t.id);
      if (i >= 0) transactions[i] = updated;
      _serverBalance = null;
      _serverStats = null;
      await _mirror();
      notifyListeners();
      return null;
    } on ApiException catch (e) {
      return e.message;
    }
  }

  Future<void> _mirror() => transactionsRepository.mirror(
    transactions,
    categoryIds: _categoryIds,
    userId: user?.id,
  );

  // ─── Dashboard computed ──────────────────────────────────
  /// Solde du serveur quand il est frais, sinon calcul local (hors-ligne).
  int get balance {
    final v = _serverBalance?['balance'];
    if (v is num) return v.round();
    return transactions.fold(0, (s, t) => s + t.signed);
  }

  List<Txn> get monthTxns {
    final now = DateTime.now();
    return transactions
        .where((t) => t.date.year == now.year && t.date.month == now.month)
        .toList();
  }

  int get monthIncome {
    final v = _serverStats?['total_income'];
    if (v is num) return v.round();
    return monthTxns
        .where((t) => t.type == TxnType.income)
        .fold(0, (s, t) => s + t.amount);
  }

  int get monthExpense {
    final v = _serverStats?['total_expenses'];
    if (v is num) return v.round();
    return monthTxns
        .where((t) => t.type == TxnType.expense)
        .fold(0, (s, t) => s + t.amount);
  }

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
      await notificationsRepository.markAllRead();
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
        await notificationsRepository.markRead(n.id!);
      } on ApiException catch (e) {
        _log.warning('markRead: ${e.message}');
      }
    }
  }

  // ─── Chat ────────────────────────────────────────────────
  Future<String> chatReply(String message) => chatRepository.reply(message);

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
        await budgetsRepository.update(
          _alimentationBudgetId!,
          amount: v.toDouble(),
        );
      } else {
        final created = await budgetsRepository.create(
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
