import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../data/repositories/shop_providers.dart';
import '../../authentication/models/user_role.dart';
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
                Text('Manage branch credentials, multi-role access, database seeds and shop defaults', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
              ],
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
            const SizedBox(height: 24),

            // Role Management Card
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
                  const Text('Active Operator Role', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                  const SizedBox(height: 6),
                  Text('Signed in as: ${user?.displayName} (${user?.email})', style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      ElevatedButton.icon(
                        icon: const Icon(Icons.swap_horiz_rounded),
                        label: Text('Switch Role to ${user?.role == UserRole.admin ? "Staff Employee" : "Administrator"}'),
                        onPressed: () {
                          final newRole = user?.role == UserRole.admin
                              ? UserRole.employee
                              : UserRole.admin;
                          ref.read(authProvider.notifier).switchRole(newRole);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Switched role to ${newRole.displayName}.')),
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Data Seed & Management Card
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
                  const Text('Sample Catalog Seeder', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                  const SizedBox(height: 6),
                  const Text('Seeds initial Oud Oils, Musks, French Blends, Bottles and EDP sprays into Firestore if empty.', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.auto_awesome_rounded, color: AppColors.primaryGold),
                    label: const Text('Seed Sample Perfume Data'),
                    onPressed: () async {
                      await ref.read(shopRepositoryProvider).seedInitialDataIfEmpty();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Sample perfume catalog verified and loaded.')),
                        );
                      }
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
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

