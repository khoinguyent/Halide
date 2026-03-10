import 'package:go_router/go_router.dart';
import '../views/home_view.dart';
import '../views/roll_detail_view.dart';
import '../views/profile_view.dart';

final appRouter = GoRouter(
  initialLocation: '/',
  routes: [
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
