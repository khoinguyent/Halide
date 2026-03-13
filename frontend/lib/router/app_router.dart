import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../views/home_view.dart';
import '../views/profile_view.dart';
import '../views/auth/login_view.dart';
import '../views/auth/register_view.dart';
import '../providers/auth_provider.dart';
import '../features/shell/presentation/widgets/halide_scaffold.dart';

// Global keys for navigation
final _rootNavigatorKey = GlobalKey<NavigatorState>();
final _shellNavigatorHomeKey = GlobalKey<NavigatorState>(debugLabel: 'home');
final _shellNavigatorProfileKey = GlobalKey<NavigatorState>(debugLabel: 'profile');

final appRouter = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: '/',
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
  redirect: (context, state) {
    final container = ProviderScope.containerOf(context);
    final user = container.read(userProvider);
    
    final loggingIn = state.matchedLocation == '/login' || state.matchedLocation == '/register';

    if (user == null) {
      if (!loggingIn) return '/login';
    } else {
      if (loggingIn) return '/';
    }

    return null;
  },
);
