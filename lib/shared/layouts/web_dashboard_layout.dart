import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../core/utils/date_formatter.dart';
import '../../features/authentication/models/user_role.dart';
import '../../features/authentication/providers/auth_provider.dart';

class WebDashboardLayout extends ConsumerWidget {
  final Widget child;
  final String currentRoute;

  const WebDashboardLayout({
    super.key,
    required this.child,
    required this.currentRoute,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final user = authState.currentUser;
    final now = DateTime.now();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Row(
        children: [
          // Left Sidebar
          Material(
            color: AppColors.sidebarBackground,
            child: SizedBox(
              width: 260,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                // Brand Header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.primaryGold.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.primaryGold.withOpacity(0.3)),
                        ),
                        child: const Icon(
                          Icons.local_fire_department_rounded,
                          color: AppColors.primaryGold,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'ZEEK',
                            style: TextStyle(
                              color: AppColors.goldLight,
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 2.0,
                            ),
                          ),
                          Text(
                            'PERFUME & ATHAR',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.6),
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 1.0,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const Divider(color: Color(0xFF23272E), height: 1),
                const SizedBox(height: 12),

                // Nav Links
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    children: [
                      _buildNavItem(
                        context: context,
                        icon: Icons.point_of_sale_rounded,
                        title: 'POS / New Sale',
                        route: '/pos',
                        isActive: currentRoute == '/pos' || currentRoute == '/',
                      ),
                      _buildNavItem(
                        context: context,
                        icon: Icons.inventory_2_outlined,
                        title: 'Inventory (Oil)',
                        route: '/inventory',
                        isActive: currentRoute == '/inventory',
                      ),
                      _buildNavItem(
                        context: context,
                        icon: Icons.business_rounded,
                        title: 'Suppliers & Vendors',
                        route: '/vendors',
                        isActive: currentRoute == '/vendors',
                      ),
                      _buildNavItem(
                        context: context,
                        icon: Icons.category_outlined,
                        title: 'Non-Oil Products',
                        route: '/non-oil',
                        isActive: currentRoute == '/non-oil',
                      ),
                      _buildNavItem(
                        context: context,
                        icon: Icons.receipt_long_outlined,
                        title: 'Sales History',
                        route: '/sales',
                        isActive: currentRoute == '/sales',
                      ),
                      _buildNavItem(
                        context: context,
                        icon: Icons.account_balance_wallet_outlined,
                        title: 'Accounts & Ledger',
                        route: '/accounts',
                        isActive: currentRoute == '/accounts',
                      ),
                      _buildNavItem(
                        context: context,
                        icon: Icons.analytics_outlined,
                        title: 'Stock Sold',
                        route: '/stock-sold',
                        isActive: currentRoute == '/stock-sold',
                      ),
                      _buildNavItem(
                        context: context,
                        icon: Icons.bar_chart_rounded,
                        title: 'Reports & Analytics',
                        route: '/reports',
                        isActive: currentRoute == '/reports',
                      ),
                      _buildNavItem(
                        context: context,
                        icon: Icons.settings_outlined,
                        title: 'Shop Settings',
                        route: '/settings',
                        isActive: currentRoute == '/settings',
                      ),
                    ],
                  ),
                ),

                // Authenticated Operator Card
                Container(
                  margin: const EdgeInsets.all(12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1F26),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFF2D3748)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.primaryGold.withOpacity(0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.verified_user_rounded,
                          color: AppColors.primaryGold,
                          size: 16,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              user?.displayName ?? 'Zeek (Owner)',
                              style: const TextStyle(
                                color: AppColors.goldLight,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              user?.email ?? '',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.5),
                                fontSize: 10,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const Divider(color: Color(0xFF23272E), height: 1),
                ListTile(
                  leading: const Icon(Icons.logout_rounded, color: AppColors.ruby, size: 20),
                  title: const Text(
                    'Logout',
                    style: TextStyle(color: AppColors.ruby, fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  onTap: () {
                    ref.read(authProvider.notifier).signOut();
                    context.go('/login');
                  },
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),

          // Main Content Viewport
          Expanded(
            child: Column(
              children: [
                // Top Navigation Bar
                Container(
                  height: 64,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  decoration: const BoxDecoration(
                    color: AppColors.surface,
                    border: Border(bottom: BorderSide(color: AppColors.border)),
                  ),
                  child: Row(
                    children: [
                      // Branch Badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.storefront_rounded, size: 16, color: AppColors.primaryGold),
                            const SizedBox(width: 8),
                            Text(
                              AppConstants.appName,
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      // Date/Time Display
                      Icon(Icons.calendar_today_outlined, size: 14, color: Colors.grey[600]),
                      const SizedBox(width: 6),
                      Text(
                        DateFormatter.formatDate(now),
                        style: TextStyle(fontSize: 13, color: Colors.grey[700], fontWeight: FontWeight.w500),
                      ),
                      const Spacer(),

                      // Active User Profile Info
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: AppColors.primaryGold.withOpacity(0.2),
                        child: Text(
                          (user?.displayName ?? 'Z').substring(0, 1).toUpperCase(),
                          style: const TextStyle(
                            color: AppColors.goldDark,
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user?.displayName ?? 'Zeek (Owner)',
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                          ),
                          Text(
                            user?.email ?? 'admin@zeekperfumes.com',
                            style: TextStyle(color: Colors.grey[600], fontSize: 11),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Active Route Content
                Expanded(
                  child: child,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String route,
    required bool isActive,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        selected: isActive,
        selectedTileColor: AppColors.primaryGold.withOpacity(0.16),
        leading: Icon(
          icon,
          size: 20,
          color: isActive ? AppColors.goldLight : Colors.white.withOpacity(0.7),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
            color: isActive ? AppColors.goldLight : Colors.white.withOpacity(0.8),
          ),
        ),
        dense: true,
        onTap: () {
          if (!isActive) {
            context.go(route);
          }
        },
      ),
    );
  }
}

