enum UserRole {
  admin,
  employee;

  String get displayName {
    switch (this) {
      case UserRole.admin:
        return 'Administrator';
      case UserRole.employee:
        return 'Sales Employee';
    }
  }

  bool get isAdmin => this == UserRole.admin;
  bool get isEmployee => this == UserRole.employee;
}

class AppUser {
  final String uid;
  final String email;
  final String displayName;
  final UserRole role;
  final String shopId;

  const AppUser({
    required this.uid,
    required this.email,
    required this.displayName,
    required this.role,
    required this.shopId,
  });

  bool get isAdmin => role.isAdmin;

  factory AppUser.mockAdmin() {
    return const AppUser(
      uid: 'admin_001',
      email: 'admin@zeekperfumes.com',
      displayName: 'Zeek (Owner)',
      role: UserRole.admin,
      shopId: 'zeek_main_branch',
    );
  }

  factory AppUser.mockEmployee() {
    return const AppUser(
      uid: 'emp_001',
      email: 'staff@zeekperfumes.com',
      displayName: 'Shop Assistant',
      role: UserRole.employee,
      shopId: 'zeek_main_branch',
    );
  }
}

