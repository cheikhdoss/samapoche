import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:samapoche/screens/add_transaction_screen.dart';
import 'package:samapoche/screens/assistant_screen.dart';
import 'package:samapoche/screens/home_screen.dart';
import 'package:samapoche/screens/login_screen.dart';
import 'package:samapoche/screens/notifications_screen.dart';
import 'package:samapoche/screens/profile_screen.dart';
import 'package:samapoche/screens/signup_screen.dart';
import 'package:samapoche/screens/transactions_screen.dart';
import 'package:samapoche/screens/welcome_screen.dart';
import 'package:samapoche/state/app_state.dart';
import 'package:samapoche/widgets/widgets.dart';

/// Routes nommées de l'application.
abstract final class Routes {
  static const welcome = '/welcome';
  static const login = '/login';
  static const signup = '/signup';
  static const home = '/home';
  static const transactions = '/transactions';
  static const assistant = '/assistant';
  static const profile = '/profile';
  static const notifications = '/notifications';
  static const add = '/add';
  static const edit = '/edit';
}

class AppRouter {
  static final Set<String> _authPaths = {
    Routes.welcome,
    Routes.login,
    Routes.signup,
  };

  /// Router unique, réactif à l'état d'authentification.
  static GoRouter create(AppState state) {
    final router = GoRouter(
      initialLocation: Routes.welcome,
      redirect: (context, routerState) {
        final logged = state.user != null;
        final at = routerState.matchedLocation;
        if (!logged && !_authPaths.contains(at)) return Routes.welcome;
        if (logged && _authPaths.contains(at)) return Routes.home;
        return null;
      },
      routes: [
        GoRoute(
          path: Routes.welcome,
          builder: (_, _) => const Scaffold(body: WelcomeScreen()),
        ),
        GoRoute(
          path: Routes.login,
          builder: (_, _) => const Scaffold(body: LoginScreen()),
        ),
        GoRoute(
          path: Routes.signup,
          builder: (_, _) => const Scaffold(body: SignupScreen()),
        ),
        GoRoute(
          path: Routes.notifications,
          builder: (_, _) => const Scaffold(body: NotificationsScreen()),
        ),
        GoRoute(
          path: Routes.add,
          builder: (_, _) => const Scaffold(body: AddTransactionScreen()),
        ),
        GoRoute(
          path: '/edit/:id',
          builder: (context, routerState) {
            final id = routerState.pathParameters['id'];
            final txn = state.transactions.where((t) => t.id == id).firstOrNull;
            return Scaffold(body: AddTransactionScreen(edit: txn));
          },
        ),
        StatefulShellRoute.indexedStack(
          builder: (context, _, shell) => _AppShell(shell: shell),
          branches: [
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: Routes.home,
                  builder: (_, _) => const HomeScreen(),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: Routes.transactions,
                  builder: (_, _) => const TransactionsScreen(),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: Routes.assistant,
                  builder: (_, _) => const AssistantScreen(),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: Routes.profile,
                  builder: (_, _) => const ProfileScreen(),
                ),
              ],
            ),
          ],
        ),
      ],
    );

    state.addListener(router.refresh);
    return router;
  }
}

/// Shell avec bottom navigation + FAB (visible uniquement sur l'accueil).
class _AppShell extends StatelessWidget {
  final StatefulNavigationShell shell;
  const _AppShell({required this.shell});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: shell,
      floatingActionButton: shell.currentIndex == 0
          ? FloatingActionButton(
              onPressed: () => context.push(Routes.add),
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Colors.white,
              elevation: 4,
              shape: const CircleBorder(),
              tooltip: 'Nouvelle transaction',
              child: const Icon(Icons.add_rounded, size: 28),
            )
          : null,
      bottomNavigationBar: AppTabBar(
        current: shell.currentIndex,
        onTap: (i) =>
            shell.goBranch(i, initialLocation: i == shell.currentIndex),
      ),
    );
  }
}
