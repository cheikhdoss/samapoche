import 'package:samapoche/services/api_client.dart';

/// Solde et statistiques mensuelles calculés côté serveur.
///
/// Source de vérité multi-appareils : l'écran d'accueil privilégie ces
/// valeurs (avec repli sur le calcul local hors-ligne / serveur injoignable).
class DashboardRepository {
  DashboardRepository({required this._api});

  final Api _api;

  Future<Map<String, dynamic>> balance() => _api.dashboardBalance();

  Future<Map<String, dynamic>> stats() => _api.dashboardStats();
}
