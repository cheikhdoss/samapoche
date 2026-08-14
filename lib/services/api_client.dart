import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

class ApiException implements Exception {
  final String message;
  final int? statusCode;
  const ApiException(this.message, {this.statusCode});

  @override
  String toString() => message;
}

class Api {
  static final I = Api._();

  static const baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:8000',
  );

  Api._();

  final http.Client _client = http.Client();
  String? token;

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
    } on http.ClientException {
      throw const ApiException('Erreur réseau. Vérifiez votre connexion.');
    }

    if (res.statusCode >= 200 && res.statusCode < 300) {
      if (res.body.isEmpty) return null;
      return jsonDecode(utf8.decode(res.bodyBytes));
    }

    String message = 'Erreur serveur (${res.statusCode}). Réessayez plus tard.';
    try {
      final data = jsonDecode(utf8.decode(res.bodyBytes));
      final detail = data['detail'];
      if (detail is String && detail.isNotEmpty) {
        message = detail;
      } else if (detail is List && detail.isNotEmpty) {
        final first = detail.first;
        if (first is Map && first['msg'] is String) {
          message = first['msg'] as String;
        }
      }
    } catch (_) {}

    if (res.statusCode == 401) {
      message = 'Session expirée. Reconnectez-vous.';
    } else if (res.statusCode == 404) {
      message = 'Ressource introuvable.';
    } else if (res.statusCode == 422) {
      message = 'Données invalides. Vérifiez votre saisie.';
    }

    throw ApiException(message, statusCode: res.statusCode);
  }

  // ─── Authentification ───────────────────────────────────
  Future<void> register({
    required String email,
    required String password,
    required String fullName,
  }) async {
    final data = await _request(
      'POST',
      '/api/v1/auth/register',
      body: {'email': email, 'password': password, 'full_name': fullName},
    );
    _storeToken(data);
  }

  Future<void> login({required String email, required String password}) async {
    final data = await _request(
      'POST',
      '/api/v1/auth/login',
      body: {'email': email, 'password': password},
    );
    _storeToken(data);
  }

  Future<Map<String, dynamic>> me() async =>
      (await _request('GET', '/api/v1/auth/me')) as Map<String, dynamic>;

  void _storeToken(dynamic data) {
    if (data is Map && data['access_token'] is String) {
      token = data['access_token'] as String;
    }
  }

  // ─── Catégories ──────────────────────────────────────────
  Future<List<dynamic>> categories() async =>
      (await _request('GET', '/api/v1/categories')) as List<dynamic>;

  // ─── Transactions ────────────────────────────────────────
  Future<List<dynamic>> transactions() async =>
      (await _request('GET', '/api/v1/transactions')) as List<dynamic>;

  Future<Map<String, dynamic>> createTransaction({
    required double amount,
    required String type,
    required int categoryId,
    String? description,
    DateTime? date,
  }) async {
    final data = await _request(
      'POST',
      '/api/v1/transactions',
      body: {
        'amount': amount,
        'type': type,
        'category_id': categoryId,
        if (description != null && description.isNotEmpty)
          'description': description,
        if (date != null) 'transaction_date': date.toUtc().toIso8601String(),
      },
    );
    return data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> updateTransaction(
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
    return data as Map<String, dynamic>;
  }

  // ─── Budgets ─────────────────────────────────────────────
  Future<List<dynamic>> budgets() async =>
      (await _request('GET', '/api/v1/budgets')) as List<dynamic>;

  Future<Map<String, dynamic>> createBudget({
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
    return data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> updateBudget(
    int id, {
    required double amount,
  }) async {
    final data = await _request(
      'PUT',
      '/api/v1/budgets/$id',
      body: {'amount': amount},
    );
    return data as Map<String, dynamic>;
  }

  // ─── Notifications ───────────────────────────────────────
  Future<List<dynamic>> notifications() async =>
      (await _request('GET', '/api/v1/notifications')) as List<dynamic>;

  Future<void> markNotificationRead(int id) async {
    await _request('PUT', '/api/v1/notifications/$id/read');
  }

  Future<void> markAllNotificationsRead() async {
    await _request('PUT', '/api/v1/notifications/read-all');
  }

  // ─── Assistant IA ────────────────────────────────────────
  Future<String> chat(String message) async {
    final data = await _request(
      'POST',
      '/api/v1/ai/chat',
      body: {'message': message},
    );
    if (data is Map && data['reply'] is String) return data['reply'] as String;
    return 'Je n\'ai pas compris votre demande. Réessayez.';
  }
}
