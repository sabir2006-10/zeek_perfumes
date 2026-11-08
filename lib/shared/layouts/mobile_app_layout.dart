import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../features/authentication/models/user_role.dart';
import '../../features/authentication/providers/auth_provider.dart';

class MobileAppLayout extends ConsumerWidget {
  final Widget child;
  final String currentRoute;

  const MobileAppLayout({
    super.key,
    required this.child,
    required this.currentRoute,
  });

  int _calculateSelectedIndex() {
    if (currentRoute == '/pos' || currentRoute == '/') return 0;
    if (currentRoute == '/inventory') return 1;
    if (currentRoute == '/sales') return 2;
    if (currentRoute == '/accounts') return 3;
    return 4; // More
  }

  void _onItemTapped(int index, BuildContext context) {
    switch (index) {
      case 0:
        context.go('/pos');
        break;
      case 1:
        context.go('/inventory');
        break;
      case 2:
        context.go('/sales');
        break;
      case 3:
        context.go('/accounts');
        break;
      case 4:
        _showMoreBottomSheet(context);
        break;
    }
  }

  void _showMoreBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return Consumer(
          builder: (context, ref, _) {
            final auth = ref.watch(authProvider);
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 16),
                    ListTile(
                      leading: const Icon(Icons.business_rounded, color: AppColors.primaryGold),
                      title: const Text('Suppliers & Vendors'),
                      subtitle: const Text('Manage wholesale vendors & purchases'),
                      onTap: () {
                        Navigator.pop(ctx);
                        context.go('/vendors');
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.category_outlined, color: AppColors.primaryGold),
                      title: const Text('Non-Oil Products'),
                      subtitle: const Text('Bottles, Sprays, Accessories'),
                      onTap: () {
                        Navigator.pop(ctx);
                        context.go('/non-oil');
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.analytics_outlined, color: AppColors.primaryGold),
                      title: const Text('Stock Sold'),
                      subtitle: const Text('Product-wise sales analytics'),
                      onTap: () {
                        Navigator.pop(ctx);
                        context.go('/stock-sold');
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.bar_chart_rounded, color: AppColors.primaryGold),
                      title: const Text('Reports & Analytics'),
                      subtitle: const Text('Daily, monthly & annual financial reports'),
                      onTap: () {
                        Navigator.pop(ctx);
                        context.go('/reports');
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.settings_outlined, color: AppColors.primaryGold),
                      title: const Text('Settings'),
                      subtitle: const Text('Shop preferences & users'),
                      onTap: () {
                        Navigator.pop(ctx);
                        context.go('/settings');
                      },
                    ),
                    const Divider(),
                    ListTile(
                      leading: const Icon(Icons.verified_user_rounded, color: AppColors.primaryGold),
                      title: Text(auth.currentUser?.displayName ?? 'Zeek (Owner)'),
                      subtitle: Text(auth.currentUser?.email ?? 'admin@zeekperfumes.com'),
                    ),
                    ListTile(
                      leading: const Icon(Icons.logout_rounded, color: AppColors.ruby),
                      title: const Text('Logout', style: TextStyle(color: AppColors.ruby)),
                      onTap: () {
                        Navigator.pop(ctx);
                        ref.read(authProvider.notifier).signOut();
                        context.go('/login');
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).currentUser;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.sidebarBackground,
        title: Row(
          children: [
            const Icon(Icons.local_fire_department_rounded, color: AppColors.primaryGold, size: 20),
            const SizedBox(width: 8),
            Text(
              AppConstants.appName,
              style: const TextStyle(
                color: AppColors.goldLight,
                fontSize: 15,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.primaryGold.withOpacity(0.2),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              user?.displayName ?? 'Zeek (Owner)',
              style: const TextStyle(color: AppColors.goldLight, fontSize: 11, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
      body: child,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _calculateSelectedIndex(),
        onTap: (idx) => _onItemTapped(idx, context),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: AppColors.primaryGold,
        unselectedItemColor: AppColors.textSecondary,
        selectedFontSize: 11,
        unselectedFontSize: 11,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.point_of_sale_rounded),
            label: 'POS',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.inventory_2_outlined),
            label: 'Inventory',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.receipt_long_outlined),
            label: 'Sales',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.account_balance_wallet_outlined),
            label: 'Accounts',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.grid_view_rounded),
            label: 'More',
          ),
        ],
      ),
    );
  }
}

