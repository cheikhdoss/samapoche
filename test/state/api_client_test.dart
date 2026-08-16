import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:samapoche/services/api_client.dart';

/// Frontière réseau : messages d'erreur FR, codes HTTP et corps incomplets.
void main() {
  Api api(MockClient client) =>
      Api(baseUrl: 'http://test.local', client: client);

  group('Erreurs réseau', () {
    test('SocketException → message utilisateur FR', () async {
      final a = api(
        MockClient((_) async => throw const SocketException('down')),
      );
      await expectLater(
        a.transactions(),
        throwsA(
          isA<ApiException>().having(
            (e) => e.message,
            'message',
            contains('Vérifiez votre connexion'),
          ),
        ),
      );
    });

    test('TimeoutException → message utilisateur FR', () async {
      final a = api(
        MockClient((_) async => throw TimeoutException('lent')),
      );
      await expectLater(
        a.transactions(),
        throwsA(
          isA<ApiException>().having(
            (e) => e.message,
            'message',
            contains('Réessayez'),
          ),
        ),
      );
    });

    test('ClientException → message utilisateur FR', () async {
      final a = api(
        MockClient((_) async => throw http.ClientException('refusé')),
      );
      await expectLater(
        a.transactions(),
        throwsA(
          isA<ApiException>().having(
            (e) => e.message,
            'message',
            contains('Erreur réseau'),
          ),
        ),
      );
    });
  });

  group('Codes HTTP', () {
    http.Response err(int code, String body) => http.Response(
      body,
      code,
      headers: {'content-type': 'application/json'},
    );

    test('401 sans preserveDetail → session expirée', () async {
      final a = api(MockClient((_) async => err(401, '{"detail": "nope"}')));
      await expectLater(
        a.me(),
        throwsA(
          isA<ApiException>().having(
            (e) => e.message,
            'message',
            'Session expirée. Reconnectez-vous.',
          ),
        ),
      );
    });

    test('login 401 → détail brut conservé (identifiants)', () async {
      final a = api(
        MockClient((_) async {
          return err(401, '{"detail": "Identifiants incorrects"}');
        }),
      );
      await expectLater(
        a.login(email: 'a@b.c', password: 'x'),
        throwsA(
          isA<ApiException>().having(
            (e) => e.message,
            'message',
            'Identifiants incorrects',
          ),
        ),
      );
    });

    test('404 → ressource introuvable', () async {
      final a = api(MockClient((_) async => err(404, '{"detail": "x"}')));
      await expectLater(
        a.transactions(),
        throwsA(
          isA<ApiException>().having(
            (e) => e.message,
            'message',
            'Ressource introuvable.',
          ),
        ),
      );
    });

    test('422 → données invalides', () async {
      final a = api(MockClient((_) async => err(422, '{"detail": "x"}')));
      await expectLater(
        a.transactions(),
        throwsA(
          isA<ApiException>().having(
            (e) => e.message,
            'message',
            'Données invalides. Vérifiez votre saisie.',
          ),
        ),
      );
    });

    test('500 avec détail string → détail réutilisé', () async {
      final a = api(
        MockClient((_) async => err(500, '{"detail": "Base de données KO"}')),
      );
      await expectLater(
        a.transactions(),
        throwsA(
          isA<ApiException>().having(
            (e) => e.message,
            'message',
            'Base de données KO',
          ),
        ),
      );
    });

    test('500 avec liste de détails → premier msg', () async {
      final a = api(
        MockClient((_) async {
          return err(
            500,
            '{"detail": [{"loc": ["body"], "msg": "champ requis", "type": "missing"}]}',
          );
        }),
      );
      await expectLater(
        a.transactions(),
        throwsA(
          isA<ApiException>().having(
            (e) => e.message,
            'message',
            'champ requis',
          ),
        ),
      );
    });

    test('500 corps non parsable → message générique', () async {
      final a = api(MockClient((_) async => err(500, 'oops')));
      await expectLater(
        a.transactions(),
        throwsA(
          isA<ApiException>().having(
            (e) => e.message,
            'message',
            'Erreur serveur (500). Réessayez plus tard.',
          ),
        ),
      );
    });
  });

  group('Succès', () {
    test('200 corps vide → null (DELETE/PUT sans retour)', () async {
      final a = api(MockClient((_) async => http.Response('', 200)));
      await a.markAllNotificationsRead();
    });

    test('login 200 → TokenDto parsé', () async {
      final a = api(
        MockClient((_) async {
          return http.Response(
            '{"access_token": "tok-x", "token_type": "bearer"}',
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      );
      final token = await a.login(email: 'a@b.c', password: 'x');

      expect(token.accessToken, 'tok-x');
    });
  });
}
