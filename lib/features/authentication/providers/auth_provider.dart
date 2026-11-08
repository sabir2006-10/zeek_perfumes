import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_role.dart';

class AuthState {
  final bool isLoading;
  final bool isInitialized;
  final AppUser? currentUser;
  final String? errorMessage;

  const AuthState({
    this.isLoading = false,
    this.isInitialized = false,
    this.currentUser,
    this.errorMessage,
  });

  bool get isAuthenticated => currentUser != null;
  bool get isAdmin => currentUser?.isAdmin ?? false;

  AuthState copyWith({
    bool? isLoading,
    bool? isInitialized,
    AppUser? currentUser,
    String? errorMessage,
    bool clearError = false,
  }) {
    return AuthState(
      isLoading: isLoading ?? this.isLoading,
      isInitialized: isInitialized ?? this.isInitialized,
      currentUser: currentUser ?? this.currentUser,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  final FirebaseAuth? _firebaseAuth;
  StreamSubscription<User?>? _authSubscription;

  AuthNotifier([this._firebaseAuth, bool autoInit = true])
      : super(AuthState(isLoading: autoInit, isInitialized: !autoInit)) {
    if (autoInit) {
      _init();
    }
  }

  void _init() {
    final auth = _firebaseAuth;
    if (auth != null) {
      // 1. Immediate sync check if already cached
      final current = auth.currentUser;
      if (current != null) {
        state = AuthState(
          isLoading: false,
          isInitialized: true,
          currentUser: _mapFirebaseUser(current),
        );
      }

      // 2. Continuous reactive listener for auth state changes (restores session after browser refresh)
      _authSubscription = auth.authStateChanges().listen(
        (user) {
          if (user != null) {
            state = AuthState(
              isLoading: false,
              isInitialized: true,
              currentUser: _mapFirebaseUser(user),
            );
          } else {
            state = const AuthState(
              isLoading: false,
              isInitialized: true,
              currentUser: null,
            );
          }
        },
        onError: (err) {
          state = AuthState(
            isLoading: false,
            isInitialized: true,
            errorMessage: err.toString(),
          );
        },
      );
    } else {
      // Running without Firebase Auth (e.g. initial setup or disconnected mode)
      state = const AuthState(
        isLoading: false,
        isInitialized: true,
        currentUser: null,
      );
    }
  }

  AppUser _mapFirebaseUser(User user) {
    return AppUser(
      uid: user.uid,
      email: user.email ?? 'admin@zeekperfumes.com',
      displayName: (user.displayName != null && user.displayName!.isNotEmpty)
          ? user.displayName!
          : 'Zeek (Owner)',
      role: UserRole.admin,
      shopId: 'zeek_main_branch',
    );
  }

  Future<bool> signInWithEmailPassword(String email, String password) async {
    final cleanEmail = email.trim();
    final cleanPassword = password.trim();

    if (cleanEmail.isEmpty || cleanPassword.isEmpty) {
      state = state.copyWith(
        errorMessage: 'Please enter both email and password.',
      );
      return false;
    }

    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final auth = _firebaseAuth;
      if (auth != null) {
        final credential = await auth.signInWithEmailAndPassword(
          email: cleanEmail,
          password: cleanPassword,
        );
        final user = credential.user;
        if (user != null) {
          state = AuthState(
            isLoading: false,
            isInitialized: true,
            currentUser: _mapFirebaseUser(user),
          );
          return true;
        }
      }

      // Fallback only if no FirebaseAuth instance
      state = state.copyWith(
        isLoading: false,
        isInitialized: true,
        currentUser: AppUser(
          uid: 'shared_zeek_user',
          email: cleanEmail,
          displayName: 'Zeek (Owner)',
          role: UserRole.admin,
          shopId: 'zeek_main_branch',
        ),
      );
      return true;
    } on FirebaseAuthException catch (e) {
      String message;
      switch (e.code) {
        case 'user-not-found':
        case 'wrong-password':
        case 'invalid-credential':
          message = 'Invalid email or password. Please verify your credentials.';
          break;
        case 'invalid-email':
          message = 'The email address format is invalid.';
          break;
        case 'user-disabled':
          message = 'This account has been disabled. Please contact the administrator.';
          break;
        case 'too-many-requests':
          message = 'Too many failed login attempts. Please try again later.';
          break;
        case 'network-request-failed':
          message = 'Network error. Please check your internet connection.';
          break;
        default:
          message = e.message ?? 'Authentication failed. Please check your credentials.';
      }
      state = state.copyWith(isLoading: false, errorMessage: message);
      return false;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'An unexpected authentication error occurred: ${e.toString()}',
      );
      return false;
    }
  }

  Future<void> signOut() async {
    state = state.copyWith(isLoading: true);
    try {
      await _firebaseAuth?.signOut();
    } catch (_) {}
    state = const AuthState(
      isLoading: false,
      isInitialized: true,
      currentUser: null,
    );
  }

  @visibleForTesting
  void setMockUser(AppUser? user) {
    state = AuthState(
      isLoading: false,
      isInitialized: true,
      currentUser: user,
    );
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  FirebaseAuth? auth;
  try {
    auth = FirebaseAuth.instance;
  } catch (_) {}
  return AuthNotifier(auth);
});
