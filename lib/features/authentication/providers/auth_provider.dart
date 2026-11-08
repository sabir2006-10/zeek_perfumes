import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_role.dart';

class AuthState {
  final bool isLoading;
  final AppUser? currentUser;
  final String? errorMessage;

  const AuthState({
    this.isLoading = false,
    this.currentUser,
    this.errorMessage,
  });

  bool get isAuthenticated => currentUser != null;
  bool get isAdmin => currentUser?.isAdmin ?? false;

  AuthState copyWith({
    bool? isLoading,
    AppUser? currentUser,
    String? errorMessage,
  }) {
    return AuthState(
      isLoading: isLoading ?? this.isLoading,
      currentUser: currentUser ?? this.currentUser,
      errorMessage: errorMessage,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  final FirebaseAuth? _firebaseAuth;

  AuthNotifier([this._firebaseAuth])
      : super(AuthState(currentUser: AppUser.mockAdmin())); // Default logged in as Admin for fast testing

  Future<void> signInWithEmailPassword(String email, String password, {UserRole role = UserRole.admin}) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      if (_firebaseAuth != null) {
        final credential = await _firebaseAuth.signInWithEmailAndPassword(
          email: email.trim(),
          password: password,
        );
        state = state.copyWith(
          isLoading: false,
          currentUser: AppUser(
            uid: credential.user?.uid ?? 'uid_${DateTime.now().millisecondsSinceEpoch}',
            email: email,
            displayName: credential.user?.displayName ?? (role == UserRole.admin ? 'Zeek (Owner)' : 'Staff Member'),
            role: role,
            shopId: 'zeek_main_branch',
          ),
        );
      } else {
        // Fallback simulated login
        await Future.delayed(const Duration(milliseconds: 300));
        state = state.copyWith(
          isLoading: false,
          currentUser: AppUser(
            uid: 'uid_${role.name}',
            email: email,
            displayName: role == UserRole.admin ? 'Zeek (Owner)' : 'Shop Staff',
            role: role,
            shopId: 'zeek_main_branch',
          ),
        );
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  void switchRole(UserRole role) {
    if (role == UserRole.admin) {
      state = state.copyWith(currentUser: AppUser.mockAdmin());
    } else {
      state = state.copyWith(currentUser: AppUser.mockEmployee());
    }
  }

  void signOut() async {
    try {
      await _firebaseAuth?.signOut();
    } catch (_) {}
    state = const AuthState(currentUser: null);
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  FirebaseAuth? auth;
  try {
    auth = FirebaseAuth.instance;
  } catch (_) {}
  return AuthNotifier(auth);
});

