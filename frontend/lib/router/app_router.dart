import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../features/shell/presentation/widgets/halide_scaffold.dart';
import '../views/home_view.dart';
import '../views/profile_view.dart';
import '../views/locker_view.dart';
import '../views/add_gear_view.dart';
import '../views/meter_view.dart';
import '../views/auth/login_view.dart';
import '../views/auth/register_view.dart';
import '../views/camera_detail_view.dart';
import '../views/roll_detail_view.dart';
import '../views/legal/privacy_policy_view.dart';
import '../views/legal/terms_conditions_view.dart';
import '../views/settings_view.dart';

// Global keys for navigation
final _rootNavigatorKey = GlobalKey<NavigatorState>();
final _shellNavigatorHomeKey = GlobalKey<NavigatorState>(debugLabel: 'home');
final _shellNavigatorLockerKey = GlobalKey<NavigatorState>(debugLabel: 'locker');
final _shellNavigatorMeterKey = GlobalKey<NavigatorState>(debugLabel: 'meter');
final _shellNavigatorProfileKey = GlobalKey<NavigatorState>(debugLabel: 'profile');

/// A ChangeNotifier that listens to Firebase auth state changes
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

    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) {
        const branchPaths = ['/', '/locker', '/meter', '/profile'];
        return HalideScaffold(
          currentIndex: navigationShell.currentIndex,
          onTabSelected: (index) {
            context.go(branchPaths[index]);
          },
          child: navigationShell,
        );
      },
      branches: [
        // Tab 1: Home
        StatefulShellBranch(
          navigatorKey: _shellNavigatorHomeKey,
          routes: [
            GoRoute(
              path: '/',
              builder: (context, state) => const HomeView(),
            ),
          ],
        ),
        // Tab 2: Locker
        StatefulShellBranch(
          navigatorKey: _shellNavigatorLockerKey,
          routes: [
            GoRoute(
              path: '/locker',
              builder: (context, state) => const LockerView(),
              routes: [
                GoRoute(
                  path: 'add-gear',
                  builder: (context, state) => const AddGearView(),
                ),
                GoRoute(
                  path: 'camera/:id',
                  builder: (context, state) {
                    final id = state.pathParameters['id']!;
                    return CameraDetailView(cameraId: id);
                  },
                ),
              ],
            ),
          ],
        ),
        // Tab 3: Meter
        StatefulShellBranch(
          navigatorKey: _shellNavigatorMeterKey,
          routes: [
            GoRoute(
              path: '/meter',
              builder: (context, state) => const MeterView(),
            ),
          ],
        ),
        // Tab 4: Profile
        StatefulShellBranch(
          navigatorKey: _shellNavigatorProfileKey,
          routes: [
            GoRoute(
              path: '/profile',
              builder: (context, state) => const ProfileView(),
              routes: [
                GoRoute(
                  path: 'settings',
                  builder: (context, state) => const SettingsView(),
                ),
                GoRoute(
                  path: 'privacy',
                  builder: (context, state) => const PrivacyPolicyView(),
                ),
                GoRoute(
                  path: 'terms',
                  builder: (context, state) => const TermsConditionsView(),
                ),
              ],
            ),
          ],
        ),
      ],
    ),
  ],
);
