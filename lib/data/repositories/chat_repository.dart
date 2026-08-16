import 'package:samapoche/services/api_client.dart';

/// Assistant IA : un appel, une réponse — aucune logique de cache.
class ChatRepository {
  final Api _api;

  ChatRepository({required this._api});

  Future<String> reply(String message) async {
    try {
      return (await _api.chat(message)).reply;
    } on ApiException catch (e) {
      return 'Je n\'ai pas pu répondre pour le moment. ${e.message}';
    }
  }
}
