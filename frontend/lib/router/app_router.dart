import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../views/home_view.dart';
import '../views/roll_detail_view.dart';
import '../views/profile_view.dart';
import '../views/auth_view.dart';

final appRouter = GoRouter(
  initialLocation: '/',
  redirect: (context, state) {
    final user = FirebaseAuth.instance.currentUser;
    final loggingIn = state.matchedLocation == '/login';

    if (user == null && !loggingIn) {
      return '/login';
    }
    if (user != null && loggingIn) {
      return '/';
    }
    return null;
  },
  routes: [
    GoRoute(
      path: '/login',
      builder: (context, state) => const AuthView(),
    ),
    GoRoute(
      path: '/',
      builder: (context, state) => const HomeView(),
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
);
