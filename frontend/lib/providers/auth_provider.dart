import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import '../services/auth_service.dart';
import '../models/user_profile.dart';
import '../services/purchase_service.dart';
import '../providers/profile_provider.dart';
import '../core/l10n/locale_provider.dart';

bool _entitlementListenerRegistered = false;

final authServiceProvider = Provider<AuthService>((ref) => AuthService());

final authStateProvider = StreamProvider<User?>((ref) {
  return ref.watch(authServiceProvider).authStateChanges;
});

final userProvider = Provider<User?>((ref) {
  final user = ref.watch(authStateProvider).value;
  if (user != null) {
    PurchaseService().logIn(user.uid);
  } else {
    PurchaseService().logOut();
  }
  return user;
});

/// Current user profile from backend (GET /api/v1/me).
final userProfileProvider = FutureProvider<UserProfile?>((ref) async {
  final user = ref.watch(userProvider);
  if (user == null) return null;

  final service = ref.watch(profileServiceProvider);
  try {
    final profile = await service.getProfile();
    final localeNotifier = ref.read(localeProvider.notifier);
    if (profile.preferredLocale != null) {
      await localeNotifier.syncFromBackend(profile.preferredLocale);
    } else if (await localeNotifier.hasExplicitLocalPreference()) {
      await localeNotifier.migrateLocalToBackend(service);
    }
    // else: no server or local choice → localeProvider stays null;
    // MaterialApp uses resolveAppLocale(null, device) → device en/vi or English.
    await service.syncDeviceTimezoneIfNeeded(profile);
    // ignore: avoid_print
    print('[Auth] Profile fetched: id=${profile.id}, plan=${profile.plan}');
    return profile;
  } catch (e) {
    // ignore: avoid_print
    print('[Auth] Failed to fetch profile: $e');
    return null;
  }
});

/// RevenueCat entitlement-derived fallback plan.
///
/// Why: app-store review devices may have purchased but backend tier sync
/// (webhook + /sync) can lag or fail. Features are gated on `userPlanProvider`,
/// so we derive an on-device plan to avoid "purchased but still locked".
UserPlan _planFromActiveEntitlementIds(Iterable<String> activeEntitlementIds) {
  if (activeEntitlementIds.isEmpty) return UserPlan.free;

  final keys = activeEntitlementIds.map((k) => k.toLowerCase());

  // Non-renewing / longer-term plans first.
  if (keys.any((k) => k.contains('lifetime'))) return UserPlan.lifetime;
  if (keys.any((k) => k.contains('annually') || k.contains('annual') || k.contains('year')))
    return UserPlan.annually;
  if (keys.any((k) => k.contains('monthly') || k.contains('month'))) return UserPlan.monthly;
  if (keys.any((k) => k.contains('weekly') || k.contains('week'))) return UserPlan.weekly;

  if (keys.any((k) => k.contains('plus'))) return UserPlan.plus;
  if (keys.any((k) => k.contains('halide_pro') || k.contains('halide pro') || k.contains('pro')))
    return UserPlan.pro;

  // Any active entitlement should imply premium access.
  return UserPlan.pro;
}

class LocalEntitlementPlanNotifier extends Notifier<UserPlan> {
  @override
  UserPlan build() => UserPlan.free;

  void updateFromActiveEntitlementIds(Iterable<String> ids) {
    state = _planFromActiveEntitlementIds(ids);
  }
}

final localEntitlementPlanProvider =
    NotifierProvider<LocalEntitlementPlanNotifier, UserPlan>(
  LocalEntitlementPlanNotifier.new,
);

final userPlanProvider = Provider<UserPlan>((ref) {
  final profileAsync = ref.watch(userProfileProvider);
  final localPlan = ref.watch(localEntitlementPlanProvider);
  final backendPlan = profileAsync.value?.plan;

  // Prefer backend for correctness once it arrives, but don't re-lock the UI
  // while backend tier sync lags behind RevenueCat.
  final plan = (backendPlan == null)
      ? localPlan
      : (backendPlan == UserPlan.free && localPlan.isPro)
          ? localPlan
          : backendPlan;
  
  // ignore: avoid_print
  print('[Auth] current plan status: $plan (backend=${profileAsync.value?.plan}, local=$localPlan, loading=${profileAsync.isLoading})');
  return plan;
});

/// Listens to RevenueCat updates and refreshes the user profile when entitlements change.
/// This handles trials ending (charging) and cancellations (downgrading) reactively.
final entitlementListenerProvider = Provider<void>((ref) {
  // We don't watch userProvider here to avoid circularity.
  // Instead, the listener is added once per app start.
  if (_entitlementListenerRegistered) return;
  _entitlementListenerRegistered = true;

  // ignore: avoid_print
  print('[Auth] Setting up RevenueCat entitlement listener (local fallback enabled)');

  // Seed local plan immediately (fixes "locked after purchase" when backend sync lags).
  Purchases.getCustomerInfo().then((customerInfo) {
    Future.microtask(() {
      final ids = customerInfo.entitlements.active.keys;
      ref
          .read(localEntitlementPlanProvider.notifier)
          .updateFromActiveEntitlementIds(ids);
    });
  }).catchError((e) {
    // ignore: avoid_print
    print('[Auth] RevenueCat getCustomerInfo failed (local fallback): $e');
  });

  Purchases.addCustomerInfoUpdateListener((customerInfo) {
      Future.microtask(() async {
      // ignore: avoid_print
      print('[Auth] RevenueCat update detected. Refreshing profile from backend (tier/storage come from DB; webhooks keep them updated)...');

      final ids = customerInfo.entitlements.active.keys;
      ref
          .read(localEntitlementPlanProvider.notifier)
          .updateFromActiveEntitlementIds(ids);

      // Do not call RevenueCat-backed /billing/sync on every SDK tick — webhooks + optional
      // post-purchase `?force_remote=true` reconcile are enough; /me reads Postgres.
      ref.invalidate(userProfileProvider);
    });
  });
});
