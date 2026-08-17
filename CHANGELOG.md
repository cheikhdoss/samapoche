# Changelog

Le format s'inspire de [Keep a Changelog](https://keepachangelog.com/fr/1.1.0/).
Ce projet respecte [Semantic Versioning](https://semver.org/lang/fr/).

Chaque release correspond à un tag `vX.Y.Z` ; la section du numéro de version
est extraite automatiquement par le workflow de release.

## [0.2.0] - 2026-08-17

### Ajouté

- **Dashboard serveur : source de vérité** — le solde et les stats du mois
  (`/dashboard/balance`, `/dashboard/stats`) sont consommés après chaque
  synchronisation ; calcul local conservé comme repli hors-ligne
- Invalidation du cache serveur après chaque écriture (ajout, édition,
  suppression de transaction) pour un affichage immédiatement exact
- Faux backend étendu (handlers `dashboard/balance` et `dashboard/stats`)
  pour les tests widget

### Corrigé

- Formatage (`dart format`) aligné pour la CI

## [0.1.0] - 2026-08-16

### Ajouté

- Mise en production du squelette applicatif SamaPoche (Android) :
  - Authentification (inscription, connexion, session persistée et sécurisée)
  - Tableau de bord (solde, budget alimentation, répartition par catégories,
    objectif d'épargne)
  - Transactions (ajout, édition, historique groupé par mois, recherche,
    filtres) avec écriture **offline-first** (file de rejeu hors-ligne)
  - Notifications (groupées, filtres lu/non lu)
  - Assistant IA (chat avec le backend AFI)
  - Profil et préférences (thème sombre, objectifs, paramètres de
    notification, diagnostic d'environnement)
- Support web expérimental (bootstrap, stockage adapté)
- Flavors **dev / staging / prod** (entrées dédiées, `applicationIdSuffix`,
  libellés d'app, badge d'environnement hors production)
- Pipeline CI GitHub Actions conforme au schéma AFI :
  analyse statique (dart format + flutter analyze) → tests unitaires/widgets
  avec couverture → E2E hermétique (faux backend injecté) → SonarQube →
  MobSF (SAST → Code scanning) → Quality Gate couverture (échelonnée, seuil
  actuel 50 %) → build APK + AAB signés (staging)
- Dependabot (pub + GitHub Actions, hebdomadaire)
- Architecture par couches : domaine, data (repositories), état
  (ChangeNotifier) ; DTO strictement confinés à la frontière réseau
- Tests : 51 tests unitaires/widgets (couverture de lignes ≈ 69 %)

### Sécurité

- Token JWT en mémoire + persistance chiffrée (FlutterSecureStorage),
  migration v1 depuis SharedPreferences
- Erreurs réseau traduites en messages utilisateur (FR) sans fuite de détail
  technique
- handler d'erreur global + Sentry (activé par `--dart-define=SENTRY_DSN`)

### Corrigé

- Crash de la page Profil en debug (marge négative du `ProfileRow`
  interdite par Container ≥ Flutter 3.13)
- Synchronisation précoce pouvant échouer si les préférences n'étaient pas
  encore chargées