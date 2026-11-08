import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../models/user_role.dart';
import '../providers/auth_provider.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailController = TextEditingController(text: 'admin@zeekperfumes.com');
  final _passwordController = TextEditingController(text: 'zeek@123');
  UserRole _selectedRole = UserRole.admin;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _handleLogin() async {
    await ref.read(authProvider.notifier).signInWithEmailPassword(
          _emailController.text,
          _passwordController.text,
          role: _selectedRole,
        );
    if (mounted && ref.read(authProvider).isAuthenticated) {
      context.go('/pos');
    }
  }

  void _quickLogin(UserRole role) {
    setState(() {
      _selectedRole = role;
      if (role == UserRole.admin) {
        _emailController.text = 'admin@zeekperfumes.com';
      } else {
        _emailController.text = 'staff@zeekperfumes.com';
      }
    });
    ref.read(authProvider.notifier).switchRole(role);
    context.go('/pos');
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    return Scaffold(
      backgroundColor: AppColors.primaryDark,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 440),
            padding: const EdgeInsets.all(36),
            decoration: BoxDecoration(
              color: const Color(0xFF1B1E23),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF2E3440)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.4),
                  blurRadius: 30,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Brand Header
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.primaryGold.withOpacity(0.12),
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.primaryGold.withOpacity(0.3)),
                    ),
                    child: const Icon(
                      Icons.local_fire_department_rounded,
                      color: AppColors.primaryGold,
                      size: 40,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                const Center(
                  child: Text(
                    'ZEEK',
                    style: TextStyle(
                      color: AppColors.goldLight,
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 4.0,
                    ),
                  ),
                ),
                Center(
                  child: Text(
                    'PERFUMES & ATHAR MANAGEMENT SYSTEM',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.55),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                if (authState.errorMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.ruby.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.ruby),
                    ),
                    child: Text(
                      authState.errorMessage!,
                      style: const TextStyle(color: AppColors.ruby, fontSize: 13),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Email field
                const Text(
                  'Email Address',
                  style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: _emailController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.email_outlined, color: AppColors.primaryGold, size: 20),
                    hintText: 'Enter shop email',
                    fillColor: Color(0xFF14171A),
                  ),
                ),
                const SizedBox(height: 16),

                // Password field
                const Text(
                  'Password',
                  style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: _passwordController,
                  obscureText: true,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.lock_outline_rounded, color: AppColors.primaryGold, size: 20),
                    hintText: 'Enter password',
                    fillColor: Color(0xFF14171A),
                  ),
                ),
                const SizedBox(height: 24),

                // Sign in button
                ElevatedButton(
                  onPressed: authState.isLoading ? null : _handleLogin,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryGold,
                    foregroundColor: AppColors.primaryDark,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: authState.isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                        )
                      : const Text(
                          'Sign In to Zeek POS',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                        ),
                ),
                const SizedBox(height: 28),

                // Quick Login Demo Buttons
                const Row(
                  children: [
                    Expanded(child: Divider(color: Color(0xFF2E3440))),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 10),
                      child: Text(
                        'QUICK DEMO ACCESS',
                        style: TextStyle(color: Colors.white38, fontSize: 11, fontWeight: FontWeight.w600),
                      ),
                    ),
                    Expanded(child: Divider(color: Color(0xFF2E3440))),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.admin_panel_settings_rounded, size: 16, color: AppColors.goldLight),
                        label: const Text('Admin', style: TextStyle(color: Colors.white, fontSize: 12)),
                        onPressed: () => _quickLogin(UserRole.admin),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFF2E3440)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.badge_outlined, size: 16, color: AppColors.primaryGold),
                        label: const Text('Staff', style: TextStyle(color: Colors.white, fontSize: 12)),
                        onPressed: () => _quickLogin(UserRole.employee),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFF2E3440)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

