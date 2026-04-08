import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/dashboard_provider.dart';
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
import '../features/storage/presentation/views/storage_account_list_view.dart';
import '../features/storage/presentation/views/storage_strategy_view.dart';
import '../views/edit_profile_view.dart';
import '../views/support_view.dart';
import '../features/billing/presentation/views/paywall_view.dart';
import '../providers/ui_state_provider.dart';

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

/// Simple observer to log screen access
class LoggingNavigatorObserver extends NavigatorObserver {
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    debugPrint('[Halide Navigation] Accessing: ${route.settings.name ?? route.toString()}');
  }
}

final appRouter = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: '/',
  refreshListenable: _authNotifier,
  observers: [LoggingNavigatorObserver()],
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
      path: '/paywall',
      builder: (context, state) => const PaywallView(),
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
        debugPrint('[Halide Navigation] Shell Tab Index: ${navigationShell.currentIndex}');
        const branchPaths = ['/', '/locker', '/meter', '/profile'];
        return _ShellArchiveRefresh(
          navigationShell: navigationShell,
          child: HalideScaffold(
            currentIndex: navigationShell.currentIndex,
            onTabSelected: (index) {
              // Using go for top-level tabs ensures state preservation in the shell
              context.go(branchPaths[index]);
            },
            child: navigationShell,
          ),
        );
      },
      branches: [
        // Tab 1: Home
        StatefulShellBranch(
          navigatorKey: _shellNavigatorHomeKey,
          observers: [LoggingNavigatorObserver()],
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
          observers: [LoggingNavigatorObserver()],
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
          observers: [LoggingNavigatorObserver()],
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
          observers: [LoggingNavigatorObserver()],
          routes: [
            GoRoute(
              path: '/profile',
              builder: (context, state) => const ProfileView(),
              routes: [
                GoRoute(
                  path: 'settings',
                  builder: (context, state) => const SettingsView(),
                  routes: [
                    GoRoute(
                      path: 'storage-strategy',
                      builder: (context, state) => const StorageStrategyView(),
                    ),
                  ],
                ),
                GoRoute(
                  path: 'edit',
                  builder: (context, state) => const EditProfileView(),
                ),
                GoRoute(
                  path: 'privacy',
                  builder: (context, state) => const PrivacyPolicyView(),
                ),
                GoRoute(
                  path: 'terms',
                  builder: (context, state) => const TermsConditionsView(),
                ),
                GoRoute(
                  path: 'support',
                  builder: (context, state) => const SupportView(),
                ),
              ],
            ),
            GoRoute(
              path: '/storage',
              builder: (context, state) => const StorageAccountListView(),
            ),
          ],
        ),
      ],
    ),
  ],
);

/// When switching bottom tabs to the Archive (home) branch, reload rolls so
/// the list reflects changes made while on other tabs.
class _ShellArchiveRefresh extends ConsumerStatefulWidget {
  final StatefulNavigationShell navigationShell;
  final Widget child;

  const _ShellArchiveRefresh({
    required this.navigationShell,
    required this.child,
  });

  @override
  ConsumerState<_ShellArchiveRefresh> createState() =>
      _ShellArchiveRefreshState();
}

class _ShellArchiveRefreshState extends ConsumerState<_ShellArchiveRefresh> {
  int? _previousIndex;

  @override
  Widget build(BuildContext context) {
    final index = widget.navigationShell.currentIndex;
    if (_previousIndex != null && index == 0 && _previousIndex != 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ref.invalidate(dashboardRollsProvider);
      });
    }
    _previousIndex = index;

    // Single source of truth for which bottom tab is active (e.g. Meter camera on/off).
    // `context.go(...)` does not always go through [HalideScaffold] tap handlers, so
    // [homeTabIndexProvider] can stay stale while the shell index changes — leaving the
    // light meter camera running off-tab. Sync shell → provider after layout.
    final tabFromProvider = ref.read(homeTabIndexProvider);
    if (tabFromProvider != index) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (ref.read(homeTabIndexProvider) != index) {
          ref.read(homeTabIndexProvider.notifier).setIndex(index);
        }
      });
    }

    return widget.child;
  }
}
