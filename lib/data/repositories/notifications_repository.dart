import 'package:samapoche/models/dto.dart';
import 'package:samapoche/services/api_client.dart';
import 'package:samapoche/services/cache.dart';

/// Notifications : lecture (avec cache hors-ligne) et marquage lu.
class NotificationsRepository {
  final Api _api;
  final CacheStore _cache;

  NotificationsRepository({required this._api, required this._cache});

  Future<List<NotificationDto>> fetch() async {
    final list = await _api.notifications();
    await _cache.storeNotifications([for (final n in list) n.toJson()]);
    return list;
  }

  Future<void> markRead(int id) => _api.markNotificationRead(id);

  Future<void> markAllRead() => _api.markAllNotificationsRead();
}
