import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../features/authentication/providers/auth_provider.dart';
import 'responsive_layout.dart';
import 'web_dashboard_layout.dart';
import 'mobile_app_layout.dart';

class AppShell extends ConsumerWidget {
  final Widget child;

  const AppShell({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);

    // If session is restoring from persistent storage (e.g. page refresh), show loading splash
    if (!authState.isInitialized) {
      return const Scaffold(
        backgroundColor: AppColors.primaryDark,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: AppColors.primaryGold),
              SizedBox(height: 16),
              Text(
                'Connecting to Zeek POS...',
                style: TextStyle(
                  color: AppColors.goldLight,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.0,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final route = GoRouterState.of(context).uri.toString();

    return ResponsiveLayout(
      mobile: MobileAppLayout(currentRoute: route, child: child),
      desktop: WebDashboardLayout(currentRoute: route, child: child),
    );
  }
}
