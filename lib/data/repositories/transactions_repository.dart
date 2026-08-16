import 'package:samapoche/domain/models.dart';
import 'package:samapoche/models/dto.dart';
import 'package:samapoche/services/api_client.dart';
import 'package:samapoche/services/cache.dart';

/// Issue d'une écriture de transaction.
sealed class CreateTxnOutcome {}

/// La transaction a été créée côté serveur (id réel).
class CreateTxnSuccess extends CreateTxnOutcome {
  final Txn txn;
  CreateTxnSuccess(this.txn);
}

/// Serveur injoignable : l'écriture est différée dans le cache hors-ligne
/// et sera rejouée à la prochaine synchronisation.
class CreateTxnDeferred extends CreateTxnOutcome {
  final int pendingCount;
  CreateTxnDeferred(this.pendingCount);
}

/// Transactions : lecture, écriture offline-first et file de rejeu.
///
/// Les réponses DTO du transport ([Api]) sont converties en modèles de
/// domaine ([Txn]) ici — c'est la frontière unique entre le réseau et l'app.
class TransactionsRepository {
  final Api _api;
  final CacheStore _cache;

  TransactionsRepository({required this._api, required this._cache});

  /// Transactions fraîches du serveur, cache rafraîchi, triées par date.
  Future<List<Txn>> fetch({required Map<int, String> categoryNames}) async {
    final list = await _api.transactions();
    await _cache.storeTransactions([for (final d in list) d.toJson()]);
    return _toDomain(list, categoryNames);
  }

  /// Dernière image connue (hors-ligne) — vide si jamais chargée.
  List<Txn> cached({required Map<int, String> categoryNames}) {
    final raw = _cache.transactions;
    if (raw == null) return [];
    return _toDomain([
      for (final e in raw)
        TransactionDto.fromJson(Map<String, dynamic>.from(e as Map)),
    ], categoryNames);
  }

  List<Txn> _toDomain(List<TransactionDto> list, Map<int, String> names) =>
      [for (final d in list) Txn.fromDto(d, names)]
        ..sort((a, b) => b.date.compareTo(a.date));

  /// Écriture offline-first : créée sur le serveur, sinon différée et rejouée
  /// à la prochaine synchronisation (l'app reste optimiste).
  Future<CreateTxnOutcome> createOfflineFirst({
    required Txn local,
    required int categoryId,
    required Map<int, String> categoryNames,
  }) async {
    try {
      final created = await _api.createTransaction(
        amount: local.amount.toDouble(),
        type: local.type == TxnType.income
            ? TransactionType.income
            : TransactionType.expense,
        categoryId: categoryId,
        description: local.description.isNotEmpty ? local.description : null,
        date: local.date,
      );
      return CreateTxnSuccess(Txn.fromDto(created, categoryNames));
    } on ApiException {
      await defer(_payload(local, categoryId));
      return CreateTxnDeferred(pendingCount);
    }
  }

  Future<Txn> update(
    int id, {
    required double amount,
    required int categoryId,
    String? description,
    required Map<int, String> categoryNames,
  }) async {
    final updated = await _api.updateTransaction(
      id,
      amount: amount,
      categoryId: categoryId,
      description: description,
    );
    return Txn.fromDto(updated, categoryNames);
  }

  // ─── File d'attente hors-ligne ───────────────────────────

  int get pendingCount => _cache.pendingTransactions?.length ?? 0;

  bool get hasPending => pendingCount > 0;

  Future<void> defer(Map<String, dynamic> payload) =>
      _cache.storePendingTransactions([
        ...(_cache.pendingTransactions ?? <dynamic>[])
            .cast<Map<String, dynamic>>(),
        payload,
      ]);

  /// Rejoue les écritures différées ; conserve uniquement celles qui échouent
  /// encore. Retourne le nombre restant en attente.
  Future<int> replayPending({required Map<int, String> categoryNames}) async {
    final pending = _cache.pendingTransactions;
    if (pending == null || pending.isEmpty) return 0;
    final remaining = <Map<String, dynamic>>[];
    for (final raw in pending) {
      final payload = raw as Map<String, dynamic>;
      try {
        await _api.createTransaction(
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
      } on ApiException {
        remaining.add(payload);
      }
    }
    if (remaining.isEmpty) {
      await _cache.clearPendingTransactions();
    } else {
      await _cache.storePendingTransactions(remaining);
    }
    return remaining.length;
  }

  /// Miroir du cache : persiste exactement ce que l'écran affiche.
  Future<void> mirror(
    List<Txn> txns, {
    required Map<String, int> categoryIds,
    int? userId,
  }) => _cache.storeTransactions([
    for (final t in txns)
      {
        'id': int.tryParse(t.id) ?? 0,
        'user_id': userId ?? 0,
        'amount': t.amount.toDouble(),
        'type': t.type.name,
        'description': t.description.isEmpty ? null : t.description,
        'category_id': categoryIds[t.category] ?? 0,
        'transaction_date': t.date.toUtc().toIso8601String(),
        'created_at': t.date.toUtc().toIso8601String(),
      },
  ]);

  static Map<String, dynamic> _payload(Txn t, int categoryId) => {
    'amount': t.amount.toDouble(),
    'type': t.type.name,
    'category_id': categoryId,
    if (t.description.isNotEmpty) 'description': t.description,
    'transaction_date': t.date.toUtc().toIso8601String(),
  };
}
