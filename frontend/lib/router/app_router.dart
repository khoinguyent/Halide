import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../features/auth/providers/auth_provider.dart'; // Adjusted path if needed, usually it's in a features folder now
import '../features/shell/presentation/widgets/halide_scaffold.dart';
import '../views/home_view.dart';
import '../views/profile_view.dart';
import '../views/auth/login_view.dart';
import '../views/auth/register_view.dart';

// Global keys for navigation
final _rootNavigatorKey = GlobalKey<NavigatorState>();
final _shellNavigatorHomeKey = GlobalKey<NavigatorState>(debugLabel: 'home');
final _shellNavigatorProfileKey = GlobalKey<NavigatorState>(debugLabel: 'profile');

/// A ChangeNotifier that listens to Firebase auth state changes
/// and notifies GoRouter to re-evaluate its redirect logic.
class AuthNotifier extends ChangeNotifier {
  AuthNotifier() {
    FirebaseAuth.instance.authStateChanges().listen((_) {
      notifyListeners();
    });
  }
}

final _authNotifier = AuthNotifier();

final appRouter = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: '/',
  refreshListenable: _authNotifier,
  redirect: (context, state) {
    final user = FirebaseAuth.instance.currentUser;
    final loggingIn =
        state.matchedLocation == '/login' ||
        state.matchedLocation == '/register';

    if (user == null && !loggingIn) {
      return '/login';
    }
    if (user != null && loggingIn) {
      return '/';
    }
    return null;
  },
  routes: [
    // Auth routes (outside the scaffold)
    GoRoute(
      path: '/login',
      builder: (context, state) => const LoginView(),
    ),
    GoRoute(
      path: '/register',
      builder: (context, state) => const RegisterView(),
    ),

    // App Shell routes
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) {
        return HalideScaffold(
          currentIndex: navigationShell.currentIndex,
          onTabSelected: (index) => navigationShell.goBranch(index),
          child: navigationShell,
        );
      },
      branches: [
        StatefulShellBranch(
          navigatorKey: _shellNavigatorHomeKey,
          routes: [
            GoRoute(
              path: '/',
              builder: (context, state) => const HomeView(),
            ),
          ],
        ),
        StatefulShellBranch(
          navigatorKey: GlobalKey<NavigatorState>(debugLabel: 'search'),
          routes: [
            GoRoute(
              path: '/search',
              builder: (context, state) => const Scaffold(body: Center(child: Text('Search'))),
            ),
          ],
        ),
        StatefulShellBranch(
          navigatorKey: GlobalKey<NavigatorState>(debugLabel: 'notifications'),
          routes: [
            GoRoute(
              path: '/notifications',
              builder: (context, state) => const Scaffold(body: Center(child: Text('Notifications'))),
            ),
          ],
        ),
        StatefulShellBranch(
          navigatorKey: _shellNavigatorProfileKey,
          routes: [
            GoRoute(
              path: '/profile',
              builder: (context, state) => const ProfileView(),
            ),
          ],
        ),
      ],
    ),
  ],
);
