import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zeek/features/authentication/models/user_role.dart';
import 'package:zeek/features/authentication/providers/auth_provider.dart';
import 'package:zeek/features/authentication/screens/login_screen.dart';
import 'package:zeek/core/routes/app_routes.dart';

void main() {
  group('Production Single-Login AuthNotifier Unit Tests', () {
    test('Initial unauthenticated state is clean and unauthenticated', () {
      final notifier = AuthNotifier(null, false);
      expect(notifier.state.isAuthenticated, isFalse);
      expect(notifier.state.currentUser, isNull);
      expect(notifier.state.errorMessage, isNull);
      expect(notifier.state.isLoading, isFalse);
      expect(notifier.state.isInitialized, isTrue);
    });

    test('Empty email or password rejects login and shows error', () async {
      final notifier = AuthNotifier(null, false);
      final success = await notifier.signInWithEmailPassword('', '');
      expect(success, isFalse);
      expect(notifier.state.isAuthenticated, isFalse);
      expect(notifier.state.errorMessage, contains('Please enter both email and password'));
    });

    test('Successful authentication sets single operator identity as Zeek (Owner)', () async {
      final notifier = AuthNotifier(null, false);
      final success = await notifier.signInWithEmailPassword('admin@zeekperfumes.com', 'securepass');
      expect(success, isTrue);
      expect(notifier.state.isAuthenticated, isTrue);
      expect(notifier.state.currentUser?.displayName, equals('Zeek (Owner)'));
      expect(notifier.state.currentUser?.email, equals('admin@zeekperfumes.com'));
      expect(notifier.state.errorMessage, isNull);
    });

    test('signOut terminates session and resets authentication state', () async {
      final notifier = AuthNotifier(null, false);
      await notifier.signInWithEmailPassword('admin@zeekperfumes.com', 'securepass');
      expect(notifier.state.isAuthenticated, isTrue);

      await notifier.signOut();
      expect(notifier.state.isAuthenticated, isFalse);
      expect(notifier.state.currentUser, isNull);
    });
  });

  group('Single Login Screen Widget Tests', () {
    testWidgets('LoginScreen renders email and password fields without hardcoded passwords', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith((ref) => AuthNotifier(null, false)),
          ],
          child: const MaterialApp(
            home: LoginScreen(),
          ),
        ),
      );

      // Verify Brand Title
      expect(find.text('ZEEK'), findsOneWidget);
      expect(find.text('PERFUMES & ATHAR MANAGEMENT SYSTEM'), findsOneWidget);

      // Verify Common Login Banner
      expect(find.text('Authorized Staff & Owner Sign-In'), findsOneWidget);

      // Verify Form inputs
      expect(find.byType(TextField), findsNWidgets(2));
      expect(find.text('Sign In to Zeek POS'), findsOneWidget);

      // Verify no quick demo buttons exist (Admin / Staff buttons must not exist)
      expect(find.text('QUICK DEMO ACCESS'), findsNothing);
      expect(find.text('Admin'), findsNothing);
      expect(find.text('Staff'), findsNothing);

      // Verify password field is empty (no hardcoded password)
      final passwordField = tester.widget<TextField>(find.byType(TextField).at(1));
      expect(passwordField.controller?.text, isEmpty);
    });

    testWidgets('LoginScreen password visibility toggle functions correctly', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith((ref) => AuthNotifier(null, false)),
          ],
          child: const MaterialApp(
            home: LoginScreen(),
          ),
        ),
      );

      // Initial state is obscured
      final passWidgetBefore = tester.widget<TextField>(find.byType(TextField).at(1));
      expect(passWidgetBefore.obscureText, isTrue);

      // Tap visibility toggle icon
      await tester.tap(find.byIcon(Icons.visibility_outlined));
      await tester.pump();

      // Now visibility icon should toggle to off and obscureText should be false
      final passWidgetAfter = tester.widget<TextField>(find.byType(TextField).at(1));
      expect(passWidgetAfter.obscureText, isFalse);
      expect(find.byIcon(Icons.visibility_off_outlined), findsOneWidget);
    });

    testWidgets('LoginScreen shows error message banner when authentication fails', (tester) async {
      final notifier = AuthNotifier(null, false);
      notifier.state = notifier.state.copyWith(
        errorMessage: 'Invalid email or password. Please verify your credentials.',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith((ref) => notifier),
          ],
          child: const MaterialApp(
            home: LoginScreen(),
          ),
        ),
      );

      expect(find.text('Invalid email or password. Please verify your credentials.'), findsOneWidget);
      expect(find.byIcon(Icons.error_outline_rounded), findsOneWidget);
    });
  });

  group('Route Access Control Guard Logic Tests', () {
    const authenticatedUser = AppUser(
      uid: 'auth_zeek_01',
      email: 'admin@zeekperfumes.com',
      displayName: 'Zeek (Owner)',
      role: UserRole.admin,
      shopId: 'zeek_main_branch',
    );

    test('Unauthenticated user is barred from /pos and redirected to /login', () {
      const state = AuthState(isInitialized: true, currentUser: null);
      final redirect = appRouteRedirect(authState: state, matchedLocation: '/pos');
      expect(redirect, equals('/login'));
    });

    test('Unauthenticated user is barred from /sales and redirected to /login', () {
      const state = AuthState(isInitialized: true, currentUser: null);
      final redirect = appRouteRedirect(authState: state, matchedLocation: '/sales');
      expect(redirect, equals('/login'));
    });

    test('Unauthenticated user is barred from /reports and redirected to /login', () {
      const state = AuthState(isInitialized: true, currentUser: null);
      final redirect = appRouteRedirect(authState: state, matchedLocation: '/reports');
      expect(redirect, equals('/login'));
    });

    test('Unauthenticated user on /login stays on /login without loop', () {
      const state = AuthState(isInitialized: true, currentUser: null);
      final redirect = appRouteRedirect(authState: state, matchedLocation: '/login');
      expect(redirect, isNull);
    });

    test('Authenticated user attempting to visit /login is redirected to /pos', () {
      const state = AuthState(isInitialized: true, currentUser: authenticatedUser);
      final redirect = appRouteRedirect(authState: state, matchedLocation: '/login');
      expect(redirect, equals('/pos'));
    });

    test('Authenticated user accessing protected routes (/pos, /sales, /reports) is permitted', () {
      const state = AuthState(isInitialized: true, currentUser: authenticatedUser);
      expect(appRouteRedirect(authState: state, matchedLocation: '/pos'), isNull);
      expect(appRouteRedirect(authState: state, matchedLocation: '/inventory'), isNull);
      expect(appRouteRedirect(authState: state, matchedLocation: '/sales'), isNull);
      expect(appRouteRedirect(authState: state, matchedLocation: '/accounts'), isNull);
      expect(appRouteRedirect(authState: state, matchedLocation: '/reports'), isNull);
      expect(appRouteRedirect(authState: state, matchedLocation: '/settings'), isNull);
    });

    test('Initializing state does not prematurely redirect during session restoration', () {
      const state = AuthState(isInitialized: false, isLoading: true, currentUser: null);
      expect(appRouteRedirect(authState: state, matchedLocation: '/pos'), isNull);
      expect(appRouteRedirect(authState: state, matchedLocation: '/sales'), isNull);
    });
  });
}
