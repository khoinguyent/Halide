import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../views/home_view.dart';
import '../views/roll_detail_view.dart';
import '../views/profile_view.dart';
import '../views/auth/login_view.dart';
import '../views/auth/register_view.dart';
import '../providers/auth_provider.dart';

final appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const HomeView(),
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
    GoRoute(
      path: '/profile',
      builder: (context, state) => const ProfileView(),
    ),
  ],
  redirect: (context, state) {
    // Check if the user is logged in
    final container = ProviderScope.containerOf(context);
    final user = container.read(userProvider);
    
    final loggingIn = state.matchedLocation == '/login' || state.matchedLocation == '/register';

    if (user == null) {
      // If not logged in and not on login/register page, redirect to login
      if (!loggingIn) return '/login';
    } else {
      // If logged in and on login/register page, redirect to home
      if (loggingIn) return '/';
    }

    return null;
  },
);
