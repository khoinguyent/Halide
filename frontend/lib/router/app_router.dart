import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../views/home_view.dart';
import '../views/roll_detail_view.dart';
import '../views/profile_view.dart';
import '../views/locker_view.dart';
import '../views/add_gear_view.dart';
import '../views/meter_view.dart';
import '../views/main_shell.dart';
import '../views/auth/login_view.dart';
import '../views/auth/register_view.dart';

class AuthNotifier extends ChangeNotifier {
  AuthNotifier() {
    FirebaseAuth.instance.authStateChanges().listen((_) {
      notifyListeners();
    });
  }
}

final _authNotifier = AuthNotifier();

final appRouter = GoRouter(
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
    ShellRoute(
      builder: (context, state, child) => MainShell(child: child),
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const HomeView(),
        ),
        GoRoute(
          path: '/locker',
          builder: (context, state) => const LockerView(),
          routes: [
            GoRoute(
              path: 'add-gear',
              builder: (context, state) => const AddGearView(),
            ),
          ],
        ),
        GoRoute(
          path: '/meter',
          builder: (context, state) => const MeterView(),
        ),
        GoRoute(
          path: '/profile',
          builder: (context, state) => const ProfileView(),
        ),
      ],
    ),
    GoRoute(
      path: '/login',
      builder: (context, state) => const LoginView(),
    ),
    GoRoute(
      path: '/register',
      builder: (context, state) => const RegisterView(),
    ),
    GoRoute(
      path: '/roll/:id',
      builder: (context, state) {
        final id = state.pathParameters['id']!;
        return RollDetailView(rollId: id);
      },
    ),
  ],
);
