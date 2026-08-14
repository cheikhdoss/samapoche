import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/models.dart';
import '../services/api_client.dart';
import '../utils/format.dart';

class AppState extends ChangeNotifier {
  static final AppState I = AppState._();

  AppState._();

  SharedPreferences? _prefs;
  bool _loaded = false;

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

  Map<int, String> get _categoryNames => {
    for (final e in _categoryIds.entries) e.value: e.key,
  };

  bool get loaded => _loaded;

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

    final savedToken = _prefs!.getString('samapoche_token');
    if (savedToken != null && savedToken.isNotEmpty) {
      Api.I.token = savedToken;
      await _restoreFromServer();
    }

    _loaded = true;
    notifyListeners();
  }

  // ─── Sync serveur ────────────────────────────────────────
  bool _syncing = false;
  bool get syncing => _syncing;

  Future<void> refresh() => _restoreFromServer();

  Future<void> _restoreFromServer() async {
    if (_syncing) return;
    _syncing = true;
    try {
      final me = await Api.I.me();
      user = UserProfile.fromServer(me);
      await _prefs!.setString('samapoche_user', jsonEncode(user!.toJson()));
      _loadCategories();
      await _syncTransactions();
      await _syncBudgets();
      await _syncNotifications();
      notifyListeners();
    } on ApiException catch (e) {
      if (e.statusCode == 401) {
        await logout(silent: true);
      } else {
        _loadFallbackCache();
        notifyListeners();
      }
    } finally {
      _syncing = false;
    }
  }

  Future<void> _loadCategories() async {
    try {
      final list = await Api.I.categories();
      _categoryIds = {
        for (final c in list) (c['name'] as String): (c['id'] as num).toInt(),
      };
      await _prefs!.setString('samapoche_categories', jsonEncode(list));
    } on ApiException {
      final cached = _prefs!.getString('samapoche_categories');
      if (cached != null) {
        final list = jsonDecode(cached) as List;
        _categoryIds = {
          for (final c in list) (c['name'] as String): (c['id'] as num).toInt(),
        };
      }
    }
    notifyListeners();
  }

  Future<void> _syncTransactions() async {
    final list = await Api.I.transactions();
    transactions = [
      for (final e in list)
        Txn.fromServer(
          e as Map<String, dynamic>,
          categoryNames: _categoryNames,
        ),
    ]..sort((a, b) => b.date.compareTo(a.date));
    await _prefs!.setString(
      'samapoche_txns',
      jsonEncode(transactions.map((t) => t.toJson()).toList()),
    );
    notifyListeners();
  }

  Future<void> _syncBudgets() async {
    final list = await Api.I.budgets();
    final now = DateTime.now();
    final current = list.where(
      (b) =>
          (b['month'] as num).toInt() == now.month &&
          (b['year'] as num).toInt() == now.year,
    );
    final alimentation = current.isNotEmpty
        ? current
        : list.where((b) => (b['category_name'] as String) == 'Alimentation');
    if (alimentation.isNotEmpty) {
      final b = alimentation.first as Map<String, dynamic>;
      _alimentationBudgetId = (b['id'] as num).toInt();
      budget = (b['amount'] as num).round();
      await _prefs!.setInt('samapoche_budget', budget);
    }
    notifyListeners();
  }

  Future<void> _syncNotifications() async {
    final list = await Api.I.notifications();
    final now = DateTime.now();
    notifications = [
      for (final n in list)
        AppNotification.fromServer(
          n as Map<String, dynamic>,
          time: _notifTime(
            DateTime.parse(n['created_at'] as String).toLocal(),
            now,
          ),
          group: _notifGroup(
            DateTime.parse(n['created_at'] as String).toLocal(),
            now,
          ),
        ),
    ];
    notifyListeners();
  }

  void _loadFallbackCache() {
    final t = _prefs!.getString('samapoche_txns');
    if (t != null) {
      try {
        transactions =
            (jsonDecode(t) as List)
                .map((e) => Txn.fromJson(e as Map<String, dynamic>))
                .toList()
              ..sort((a, b) => b.date.compareTo(a.date));
      } catch (_) {}
    }
    final u = _prefs!.getString('samapoche_user');
    if (u != null) {
      try {
        user = UserProfile.fromJson(jsonDecode(u) as Map<String, dynamic>);
      } catch (_) {}
    }
  }

  // ─── Auth ────────────────────────────────────────────────
  Future<String?> signup(UserProfile p, String password) async {
    try {
      await Api.I.register(
        email: p.email,
        password: password,
        fullName: p.fullName,
      );
      await _prefs!.setString('samapoche_token', Api.I.token!);
      await _restoreFromServer();
      return null;
    } on ApiException catch (e) {
      return e.message;
    }
  }

  Future<String?> login(String email, String password) async {
    try {
      await Api.I.login(email: email, password: password);
      await _prefs!.setString('samapoche_token', Api.I.token!);
      await _restoreFromServer();
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
    Api.I.token = null;
    _alimentationBudgetId = null;
    if (_prefs != null) {
      await _prefs!.remove('samapoche_token');
      await _prefs!.remove('samapoche_user');
    }
    if (!silent) notifyListeners();
  }

  Future<void> saveProfile(UserProfile p) async {
    user = p;
    await _prefs!.setString('samapoche_user', jsonEncode(p.toJson()));
    notifyListeners();
  }

  // ─── Transactions ────────────────────────────────────────
  Future<String?> addTxn(Txn t) async {
    final catId = _categoryIds[t.category];
    if (catId == null) return 'Catégorie inconnue du serveur.';
    try {
      final created = await Api.I.createTransaction(
        amount: t.amount.toDouble(),
        type: t.type.name,
        categoryId: catId,
        description: t.description.isNotEmpty ? t.description : null,
        date: t.date,
      );
      transactions.insert(
        0,
        Txn.fromServer(created, categoryNames: _categoryNames),
      );
      await _prefs!.setString(
        'samapoche_txns',
        jsonEncode(transactions.map((x) => x.toJson()).toList()),
      );
      notifyListeners();
      return null;
    } on ApiException catch (e) {
      return e.message;
    }
  }

  Future<String?> updateTxn(Txn t) async {
    final id = int.tryParse(t.id);
    if (id == null) return 'Transaction introuvable.';
    final catId = _categoryIds[t.category];
    if (catId == null) return 'Catégorie inconnue du serveur.';
    try {
      await Api.I.updateTransaction(
        id,
        amount: t.amount.toDouble(),
        categoryId: catId,
        description: t.description.isNotEmpty ? t.description : null,
      );
      final i = transactions.indexWhere((x) => x.id == t.id);
      if (i >= 0) transactions[i] = t;
      await _prefs!.setString(
        'samapoche_txns',
        jsonEncode(transactions.map((x) => x.toJson()).toList()),
      );
      notifyListeners();
      return null;
    } on ApiException catch (e) {
      return e.message;
    }
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
    for (final n in notifications) {
      n.read = true;
    }
    notifyListeners();
    try {
      await Api.I.markAllNotificationsRead();
    } on ApiException catch (_) {}
  }

  Future<void> markRead(AppNotification n) async {
    n.read = true;
    notifyListeners();
    if (n.id != null) {
      try {
        await Api.I.markNotificationRead(n.id!);
      } on ApiException catch (_) {}
    }
  }

  // ─── Chat ────────────────────────────────────────────────
  Future<String> chatReply(String message) async {
    try {
      return await Api.I.chat(message);
    } on ApiException catch (e) {
      return 'Je n\'ai pas pu répondre pour le moment. ${e.message}';
    }
  }

  void clearChat() {
    chat.clear();
    chat.add(
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
        await Api.I.updateBudget(_alimentationBudgetId!, amount: v.toDouble());
      } else {
        final created = await Api.I.createBudget(
          categoryId: catId,
          amount: v.toDouble(),
          month: now.month,
          year: now.year,
        );
        _alimentationBudgetId = (created['id'] as num).toInt();
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
  Future<void> setDarkMode(bool v) async {
    darkMode = v;
    await _prefs!.setBool('samapoche_dark', v);
    notifyListeners();
  }

  Future<void> setGoal(int v) async {
    savingsGoal = v;
    await _prefs!.setInt('samapoche_goal', v);
    notifyListeners();
  }

  Future<void> setPref(String key, bool v) async {
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
