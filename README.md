# SamaPoche 💰

Application Flutter de **gestion financière personnelle** — Gérez mieux. Économisez plus.

Application réelle développée en Flutter, reproduisant fidèlement le design d'un prototype (iPhone frame) : tokens de design, typographie Inter, palette verte, dark mode.

## 🔄 Pipeline CI/CD

Le pipeline CI/CD du projet (Gitflow, tests, SonarQube, Docker, Terraform, K8S, observabilité) :

![Pipeline CI/CD — SamaPoche (Flutter + Supabase)](https://koboyo.com/e/d77de1ed-e27b-4155-b385-fda7e84cc06d/0d2fecf1-13de-48b8-aa9c-6bd697f9c515.svg)

## ✨ Fonctionnalités

| Écran | Description |
|---|---|
| **Welcome / Signup / Login** | Validation réelle (mot de passe 8+ chars, confirmation, CGU), compte persistant, mot de passe hashé (SHA-256) |
| **Accueil** | Solde total dynamique, revenus/dépenses mensuels, insight IA, budget Alimentation avec barre de progression, donut de répartition des dépenses, transactions récentes |
| **Nouvelle transaction** | Ajout réel (dépense/revenu, 8 catégories colorées, description, date, paiement) — le dashboard se met à jour instantanément |
| **Transactions** | Recherche temps réel, filtres fonctionnels (catégorie, montant, type, période), regroupement par mois, détail + modification |
| **Assistant IA** | Chat avec réponses par mots-clés (budget, dépenses, épargne, conseils…), copie de message, export de conversation |
| **Notifications** | Groupées par période, filtres Toutes/Non lues/Lues, tout marquer comme lu |
| **Profil** | Avatar + initiales, budget éditable, préférences, **mode sombre persistant**, déconnexion |

## 🛠️ Stack

- **Flutter** 3.44 (web + Android + iOS)
- **shared_preferences** — persistance locale (profil, transactions, réglages)
- **crypto** — hash SHA-256 du mot de passe
- Police **Inter** incluse en assets (400 → 800)
- Design system maison : tokens clair/sombre (`theme.dart`)

## 🚀 Lancer

```bash
flutter pub get
flutter run -d chrome    # web
flutter run              # device Android/iOS
flutter build apk --release   # APK Android
```

## 📁 Structure

```
lib/
├── main.dart              # bootstrap + routes
├── theme.dart             # design tokens (clair/sombre)
├── models/                # Transaction, UserProfile, Notification, ChatMessage
├── state/app_state.dart   # état global + persistance + logique métier
├── utils/format.dart      # formatage montants F CFA / dates françaises
├── widgets/               # boutons, chips, toasts, modales, tab bar
└── screens/               # welcome, login, signup, home, add, transactions,
                           # assistant, notifications, profile
```

## ✅ Qualité

- `flutter analyze` → 0 issue
- `flutter test` → 8 tests passés (formatage + smoke tests)
