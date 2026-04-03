import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import '../services/auth_service.dart';
import '../models/user_profile.dart';
import '../services/purchase_service.dart';
import '../providers/profile_provider.dart';

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
    // ignore: avoid_print
    print('[Auth] Profile fetched: id=${profile.id}, plan=${profile.plan}');
    return profile;
  } catch (e) {
    // ignore: avoid_print
    print('[Auth] Failed to fetch profile: $e');
    return null;
  }
});

final userPlanProvider = Provider<UserPlan>((ref) {
  final profileAsync = ref.watch(userProfileProvider);
  final plan = profileAsync.value?.plan ?? UserPlan.free;
  
  // ignore: avoid_print
  print('[Auth] current plan status: $plan (loading=${profileAsync.isLoading})');
  return plan;
});

/// Listens to RevenueCat updates and refreshes the user profile when entitlements change.
/// This handles trials ending (charging) and cancellations (downgrading) reactively.
final entitlementListenerProvider = Provider<void>((ref) {
  // We don't watch userProvider here to avoid circularity.
  // Instead, the listener is added once.
  
  // ignore: avoid_print
  print('[Auth] Setting up RevenueCat entitlement listener');
  
  Purchases.addCustomerInfoUpdateListener((customerInfo) {
    // ignore: avoid_print
    print('[Auth] RevenueCat update detected. Refreshing profile if user is logged in...');
    ref.invalidate(userProfileProvider);
  });
});
