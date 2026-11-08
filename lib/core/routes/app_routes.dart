import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/authentication/providers/auth_provider.dart';
import '../../features/authentication/screens/login_screen.dart';
import '../../features/pos/screens/pos_screen.dart';
import '../../features/inventory/screens/inventory_screen.dart';
import '../../features/non_oil/screens/non_oil_screen.dart';
import '../../features/vendors/screens/vendors_screen.dart';
import '../../features/sales/screens/sales_screen.dart';
import '../../features/accounts/screens/accounts_screen.dart';
import '../../features/stock_sold/screens/stock_sold_screen.dart';
import '../../features/reports/screens/reports_screen.dart';
import '../../features/settings/screens/settings_screen.dart';
import '../../shared/layouts/app_shell.dart';

final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>();
final GlobalKey<NavigatorState> _shellNavigatorKey = GlobalKey<NavigatorState>();

/// Pure route guard logic for single-login authentication & access control.
String? appRouteRedirect({
  required AuthState authState,
  required String matchedLocation,
}) {
  // 1. If Firebase Auth is still restoring session from browser/app cache, do not redirect yet
  if (!authState.isInitialized) {
    return null;
  }

  final isAuthenticated = authState.isAuthenticated;
  final isLoggingIn = matchedLocation == '/login';

  // 2. Unauthenticated users are strictly barred from accessing any protected screens
  if (!isAuthenticated) {
    return isLoggingIn ? null : '/login';
  }

  // 3. Authenticated users are prevented from lingering on /login
  if (isLoggingIn) {
    return '/pos';
  }

  // 4. Proceed to authorized route
  return null;
}

/// Bridges Riverpod's AuthNotifier state changes to GoRouter's refreshListenable.
class RouterRefreshNotifier extends ChangeNotifier {
  final Ref _ref;

  RouterRefreshNotifier(this._ref) {
    _ref.listen<AuthState>(
      authProvider,
      (previous, next) {
        if (previous?.isAuthenticated != next.isAuthenticated ||
            previous?.isInitialized != next.isInitialized) {
          notifyListeners();
        }
      },
    );
  }
}

final routerRefreshProvider = Provider<RouterRefreshNotifier>((ref) {
  return RouterRefreshNotifier(ref);
});

final routerProvider = Provider<GoRouter>((ref) {
  final refreshNotifier = ref.watch(routerRefreshProvider);

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    refreshListenable: refreshNotifier,
    initialLocation: '/pos',
    redirect: (context, state) {
      return appRouteRedirect(
        authState: ref.read(authProvider),
        matchedLocation: state.matchedLocation,
      );
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      ShellRoute(
        navigatorKey: _shellNavigatorKey,
        builder: (context, state, child) {
          return AppShell(child: child);
        },
        routes: [
          GoRoute(
            path: '/',
            redirect: (_, __) => '/pos',
          ),
          GoRoute(
            path: '/pos',
            builder: (context, state) => const PosScreen(),
          ),
          GoRoute(
            path: '/inventory',
            builder: (context, state) => const InventoryScreen(),
          ),
          GoRoute(
            path: '/vendors',
            builder: (context, state) => const VendorsScreen(),
          ),
          GoRoute(
            path: '/non-oil',
            builder: (context, state) => const NonOilScreen(),
          ),
          GoRoute(
            path: '/sales',
            builder: (context, state) => const SalesScreen(),
          ),
          GoRoute(
            path: '/accounts',
            builder: (context, state) => const AccountsScreen(),
          ),
          GoRoute(
            path: '/stock-sold',
            builder: (context, state) => const StockSoldScreen(),
          ),
          GoRoute(
            path: '/reports',
            builder: (context, state) => const ReportsScreen(),
          ),
          GoRoute(
            path: '/settings',
            builder: (context, state) => const SettingsScreen(),
          ),
        ],
      ),
    ],
  );
});
