import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../authentication/providers/auth_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    final user = auth.currentUser;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Shop Settings & Administration', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                Text('Manage shop identity, credentials and shop defaults', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
              ],
            ),
            const SizedBox(height: 24),

            // Active Operator & Security Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Operator Session & Authentication', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.primaryGold.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: AppColors.primaryGold.withOpacity(0.3)),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.verified_user_rounded, color: AppColors.primaryGold, size: 14),
                            SizedBox(width: 6),
                            Text('Authenticated', style: TextStyle(color: AppColors.goldLight, fontSize: 11, fontWeight: FontWeight.w700)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildSettingRow('Signed In As', user?.displayName ?? 'Zeek (Owner)'),
                  const Divider(height: 20),
                  _buildSettingRow('Authorized Email', user?.email ?? 'admin@zeekperfumes.com'),
                  const Divider(height: 20),
                  _buildSettingRow('Auth Provider', 'Firebase Email/Password (Single Shared Access)'),
                  const Divider(height: 20),
                  _buildSettingRow('Database Scope', 'Authenticated R/W access for zeek-perfume-5620f'),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      ElevatedButton.icon(
                        icon: const Icon(Icons.logout_rounded, size: 18),
                        label: const Text('Sign Out of POS'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.ruby,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        ),
                        onPressed: () => _confirmSignOut(context, ref),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Shop Details Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Shop Identity & Location', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                  const SizedBox(height: 16),
                  _buildSettingRow('Shop Trade Name', AppConstants.appName),
                  const Divider(height: 20),
                  _buildSettingRow('Shop Branch Code', AppConstants.defaultShopId),
                  const Divider(height: 20),
                  _buildSettingRow('Base Currency', '${AppConstants.currencySymbol} (INR - Indian Rupee)'),
                  const Divider(height: 20),
                  _buildSettingRow('Shop Timezone', AppConstants.defaultTimezone),
                  const Divider(height: 20),
                  _buildSettingRow('Cloud Database Project', 'zeek-perfume-5620f (Firebase Firestore)'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmSignOut(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Sign Out of Zeek POS', style: TextStyle(fontWeight: FontWeight.w700)),
        content: const Text(
          'Are you sure you want to end your current session? You will need the shared shop password to sign in again.',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.ruby,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(dialogCtx);
              ref.read(authProvider.notifier).signOut();
              context.go('/login');
            },
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingRow(String title, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
        Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
      ],
    );
  }
}
