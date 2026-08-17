import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';

import 'package:samapoche/models/dto.dart';

class ApiException implements Exception {
  final String message;
  final int? statusCode;
  const ApiException(this.message, {this.statusCode});

  @override
  String toString() => message;
}

/// Client HTTP typé vers l'API AFI (FastAPI).
///
/// Les réponses sont parsées en DTO (json_serializable) : la frontière
/// réseau est typée, plus aucun `as Map<String, dynamic>` dans l'app.
class Api {
  final http.Client _client;
  final String baseUrl;
  final Logger _log = Logger('Api');

  String? token;

  Api({required this.baseUrl, http.Client? client})
    : _client = client ?? http.Client();

  Uri _uri(String path) => Uri.parse('$baseUrl$path');

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
    if (token != null) 'Authorization': 'Bearer $token',
  };

  Future<dynamic> _request(
    String method,
    String path, {
    Map<String, dynamic>? body,
    bool preserveDetail = false,
  }) async {
    final uri = _uri(path);
    http.Response res;
    try {
      final encoded = body == null ? null : jsonEncode(body);
      res = switch (method) {
        'GET' =>
          await _client
              .get(uri, headers: _headers)
              .timeout(const Duration(seconds: 15)),
        'POST' =>
          await _client
              .post(uri, headers: _headers, body: encoded)
              .timeout(const Duration(seconds: 15)),
        'PUT' =>
          await _client
              .put(uri, headers: _headers, body: encoded)
              .timeout(const Duration(seconds: 15)),
        'DELETE' =>
          await _client
              .delete(uri, headers: _headers)
              .timeout(const Duration(seconds: 15)),
        _ => throw ArgumentError('Méthode HTTP inconnue : $method'),
      };
    } on SocketException {
      throw const ApiException(
        'Impossible de joindre le serveur. Vérifiez votre connexion.',
      );
    } on TimeoutException {
      throw const ApiException(
        'Le serveur met trop de temps à répondre. Réessayez.',
      );
    } on http.ClientException catch (e) {
      throw ApiException(
        'Erreur réseau. Vérifiez votre connexion. (${e.message})',
      );
    }

    if (res.statusCode >= 200 && res.statusCode < 300) {
      if (res.body.isEmpty) return null;
      return jsonDecode(utf8.decode(res.bodyBytes));
    }

    var message = 'Erreur serveur (${res.statusCode}). Réessayez plus tard.';
    try {
      final data =
          jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
      final rawDetail = data['detail'];
      if (rawDetail is String && rawDetail.isNotEmpty) {
        message = rawDetail;
      } else if (rawDetail is List && rawDetail.isNotEmpty) {
        final first = rawDetail.first;
        if (first is Map<String, dynamic> && first['msg'] is String) {
          message = first['msg'] as String;
        }
      }
    } on Exception catch (e) {
      _log.warning('Réponse d\'erreur non parsable ($method $path): $e');
    }

    if (res.statusCode == 401 && !preserveDetail) {
      message = 'Session expirée. Reconnectez-vous.';
    } else if (res.statusCode == 404) {
      message = 'Ressource introuvable.';
    } else if (res.statusCode == 422) {
      message = 'Données invalides. Vérifiez votre saisie.';
    }

    throw ApiException(message, statusCode: res.statusCode);
  }

  // ─── Authentification ───────────────────────────────────
  Future<TokenDto> register({
    required String email,
    required String password,
    required String fullName,
  }) async {
    final data = await _request(
      'POST',
      '/api/v1/auth/register',
      body: {'email': email, 'password': password, 'full_name': fullName},
    );
    return TokenDto.fromJson(data as Map<String, dynamic>);
  }

  Future<TokenDto> login({
    required String email,
    required String password,
  }) async {
    final data = await _request(
      'POST',
      '/api/v1/auth/login',
      body: {'email': email, 'password': password},
      preserveDetail: true,
    );
    return TokenDto.fromJson(data as Map<String, dynamic>);
  }

  Future<UserDto> me() async {
    final data = await _request('GET', '/api/v1/auth/me');
    return UserDto.fromJson(data as Map<String, dynamic>);
  }

  // ─── Catégories ──────────────────────────────────────────
  Future<List<CategoryDto>> categories() async {
    final list = await _request('GET', '/api/v1/categories') as List<dynamic>;
    return [
      for (final e in list) CategoryDto.fromJson(e as Map<String, dynamic>),
    ];
  }

  // ─── Transactions ────────────────────────────────────────
  Future<List<TransactionDto>> transactions() async {
    final list = await _request('GET', '/api/v1/transactions') as List<dynamic>;
    return [
      for (final e in list) TransactionDto.fromJson(e as Map<String, dynamic>),
    ];
  }

  Future<TransactionDto> createTransaction({
    required double amount,
    required TransactionType type,
    required int categoryId,
    String? description,
    DateTime? date,
  }) async {
    final data = await _request(
      'POST',
      '/api/v1/transactions',
      body: {
        'amount': amount,
        'type': type.name,
        'category_id': categoryId,
        if (description != null && description.isNotEmpty)
          'description': description,
        if (date != null) 'transaction_date': date.toUtc().toIso8601String(),
      },
    );
    return TransactionDto.fromJson(data as Map<String, dynamic>);
  }

  Future<TransactionDto> updateTransaction(
    int id, {
    required double amount,
    required int categoryId,
    String? description,
  }) async {
    final data = await _request(
      'PUT',
      '/api/v1/transactions/$id',
      body: {
        'amount': amount,
        'category_id': categoryId,
        if (description != null && description.isNotEmpty)
          'description': description,
      },
    );
    return TransactionDto.fromJson(data as Map<String, dynamic>);
  }

  // ─── Budgets ─────────────────────────────────────────────
  Future<List<BudgetStatusDto>> budgets() async {
    final list = await _request('GET', '/api/v1/budgets') as List<dynamic>;
    return [
      for (final e in list) BudgetStatusDto.fromJson(e as Map<String, dynamic>),
    ];
  }

  Future<BudgetResponseDto> createBudget({
    required int categoryId,
    required double amount,
    required int month,
    required int year,
  }) async {
    final data = await _request(
      'POST',
      '/api/v1/budgets',
      body: {
        'category_id': categoryId,
        'amount': amount,
        'month': month,
        'year': year,
      },
    );
    return BudgetResponseDto.fromJson(data as Map<String, dynamic>);
  }

  Future<BudgetResponseDto> updateBudget(
    int id, {
    required double amount,
  }) async {
    final data = await _request(
      'PUT',
      '/api/v1/budgets/$id',
      body: {'amount': amount},
    );
    return BudgetResponseDto.fromJson(data as Map<String, dynamic>);
  }

  // ─── Notifications ───────────────────────────────────────
  Future<List<NotificationDto>> notifications() async {
    final list =
        await _request('GET', '/api/v1/notifications') as List<dynamic>;
    return [
      for (final e in list) NotificationDto.fromJson(e as Map<String, dynamic>),
    ];
  }

  Future<void> markNotificationRead(int id) async {
    await _request('PUT', '/api/v1/notifications/$id/read');
  }

  Future<void> markAllNotificationsRead() async {
    await _request('PUT', '/api/v1/notifications/read-all');
  }

  // ─── Dashboard ───────────────────────────────────────────
  Future<Map<String, dynamic>> dashboardBalance() async =>
      await _request('GET', '/api/v1/dashboard/balance')
          as Map<String, dynamic>;

  Future<Map<String, dynamic>> dashboardStats() async =>
      await _request('GET', '/api/v1/dashboard/stats') as Map<String, dynamic>;

  // ─── Assistant IA ────────────────────────────────────────
  Future<ChatReplyDto> chat(String message) async {
    final data = await _request(
      'POST',
      '/api/v1/ai/chat',
      body: {'message': message},
    );
    return ChatReplyDto.fromJson(data as Map<String, dynamic>);
  }
}
