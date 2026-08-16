import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:samapoche/services/api_client.dart';
import 'package:samapoche/services/cache.dart';
import 'package:samapoche/services/token_storage.dart';
import 'package:samapoche/state/app_state.dart';

const seedCategoryNames = [
  'Alimentation',
  'Transport',
  'Logement',
  'Loisirs',
  'Santé',
  'Éducation',
  'Shopping',
  'Salaire',
  'Autres',
];

String _isoDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

http.Response _json(Object body) => http.Response(
  jsonEncode(body),
  200,
  headers: {'content-type': 'application/json'},
);

http.Response _err(int code, String detail) => http.Response(
  jsonEncode({'detail': detail}),
  code,
  headers: {'content-type': 'application/json'},
);

/// Commutateurs de comportement du faux backend (mutables à chaud).
class TestControls {
  bool networkDown = false;
  bool expiredToken = false;
}

/// Faux backend reproduisant le contrat `/api/v1` de AFI.
class TestBackend {
  TestBackend(this.controls);

  final TestControls controls;
  late final MockClient client = MockClient(_handler);

  /// Store en mémoire, cohérent avec les écritures du client (POST/PUT).
  final List<Map<String, dynamic>> transactions = [
    {
      'id': 1,
      'user_id': 1,
      'amount': 2500.0,
      'type': 'expense',
      'description': 'Riz bag',
      'category_id': 1,
      'transaction_date': _isoDate(
        DateTime.now().subtract(const Duration(days: 1)),
      ),
      'created_at': DateTime.now()
          .subtract(const Duration(days: 1))
          .toIso8601String(),
    },
    {
      'id': 2,
      'user_id': 1,
      'amount': 150000.0,
      'type': 'income',
      'description': 'Salaire',
      'category_id': 8,
      'transaction_date': _isoDate(
        DateTime.now().subtract(const Duration(days: 14)),
      ),
      'created_at': DateTime.now()
          .subtract(const Duration(days: 14))
          .toIso8601String(),
    },
  ];

  Future<http.Response> _handler(http.Request request) async {
    final c = controls;
    if (c.networkDown) {
      throw http.ClientException('Réseau indisponible (test)');
    }
    if (c.expiredToken) return _err(401, 'Token expiré');

    final p = request.url.path;
    if (!p.startsWith('/api/v1/')) return _err(404, 'Endpoint inconnu: $p');

    if (p == '/api/v1/auth/login') {
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      if (body['password'] == 'wrong') {
        return _err(401, 'Identifiants incorrects');
      }
      return _json({'access_token': 'tok-test', 'token_type': 'bearer'});
    }
    if (p == '/api/v1/auth/register') {
      return _json({'access_token': 'tok-test', 'token_type': 'bearer'});
    }
    if (p == '/api/v1/auth/me') {
      return _json({
        'id': 1,
        'email': 'user@test.dev',
        'full_name': 'Test User',
      });
    }
    if (p == '/api/v1/categories') {
      return _json([
        for (var i = 0; i < seedCategoryNames.length; i++)
          {
            'id': i + 1,
            'name': seedCategoryNames[i],
            'icon': 'circle',
            'color': '#000000',
          },
      ]);
    }

    if (p == '/api/v1/transactions' && request.method == 'GET') {
      return _json(transactions);
    }
    if (p == '/api/v1/transactions' && request.method == 'POST') {
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      final created = {
        'id': 10,
        'user_id': 1,
        ...body,
        'created_at': DateTime.now().toIso8601String(),
      };
      transactions.insert(0, created);
      return _json(created);
    }
    final txPut = RegExp(r'^/api/v1/transactions/(\d+)$').firstMatch(p);
    if (txPut != null && request.method == 'PUT') {
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      final updated = {
        'id': int.parse(txPut.group(1)!),
        'user_id': 1,
        ...body,
        'created_at': DateTime.now().toIso8601String(),
      };
      final i = transactions.indexWhere((t) => t['id'] == updated['id']);
      if (i >= 0) transactions[i] = updated;
      return _json(updated);
    }

    if (p == '/api/v1/budgets' && request.method == 'GET') {
      return _json([
        {
          'id': 1,
          'user_id': 1,
          'category_id': 1,
          'category_name': 'Alimentation',
          'amount': 50000,
          'spent': 2500,
          'percentage': 5.0,
          'alert_80': false,
          'alert_100': false,
          'remaining': 47500,
        },
      ]);
    }
    if (p == '/api/v1/budgets' && request.method == 'POST') {
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      return _json({'id': 1, 'user_id': 1, ...body});
    }
    final budgetPut = RegExp(r'^/api/v1/budgets/(\d+)$').firstMatch(p);
    if (budgetPut != null && request.method == 'PUT') {
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      return _json({
        'id': int.parse(budgetPut.group(1)!),
        'user_id': 1,
        ...body,
      });
    }

    if (p == '/api/v1/notifications' && request.method == 'GET') {
      return _json([
        {
          'id': 1,
          'title': 'Budget Alimentation',
          'message': 'Alimentation à 5%',
          'icon': 'info',
          'read': false,
          'created_at': DateTime.now()
              .subtract(const Duration(days: 1))
              .toIso8601String(),
        },
      ]);
    }
    if (p.startsWith('/api/v1/notifications/')) return _json({'ok': true});

    if (p == '/api/v1/ai/chat') {
      return _json({
        'reply': 'Bonjour ! Voici un conseil.',
        'conversation_id': 'conv-1',
      });
    }

    return _err(404, 'Endpoint inconnu: $p');
  }
}

/// Contexte de test : état applicatif branché sur le faux backend.
class TestContext {
  TestContext({required this.state, required this.backend});

  final AppState state;
  final TestBackend backend;
}

Future<TestContext> createTestContext() async {
  final backend = TestBackend(TestControls());
  final state = AppState(
    api: Api(baseUrl: 'http://test.local', client: backend.client),
    cache: MemoryCache(),
    tokenStorage: TokenStorage(storage: _FakeSecureStorage()),
  );
  return TestContext(state: state, backend: backend);
}

/// Remplace le stockage DPAPI/Keychain par une version en mémoire pour les tests.
class _FakeSecureStorage extends FlutterSecureStorage {
  String? _value;

  @override
  Future<String?> read({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async => _value;

  @override
  Future<void> write({
    required String key,
    required String? value,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    _value = value;
  }

  @override
  Future<void> delete({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    _value = null;
  }
}
