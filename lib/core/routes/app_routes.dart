import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
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

final appRouter = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: '/pos',
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

