import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'responsive_layout.dart';
import 'web_dashboard_layout.dart';
import 'mobile_app_layout.dart';

class AppShell extends StatelessWidget {
  final Widget child;

  const AppShell({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final route = GoRouterState.of(context).uri.toString();

    return ResponsiveLayout(
      mobile: MobileAppLayout(currentRoute: route, child: child),
      desktop: WebDashboardLayout(currentRoute: route, child: child),
    );
  }
}

