import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import '../config/app_config.dart';
import '../config/env_loader.dart';

class PurchaseService {
  static final PurchaseService _instance = PurchaseService._internal();
  factory PurchaseService() => _instance;
  PurchaseService._internal();

  // RevenueCat: `frontend/.env` first, then --dart-define; last resort test key.
  static String get _apiKeyApple => halideEnvString(
        'REVENUE_CAT_APPLE_KEY',
        fromDefine: const String.fromEnvironment(
          'REVENUE_CAT_APPLE_KEY',
          defaultValue: 'test_wyzkattJBBUIIymeWTHhZNZUwke',
        ),
      );

  static String get _apiKeyGoogle => halideEnvString(
        'REVENUE_CAT_GOOGLE_KEY',
        fromDefine: const String.fromEnvironment(
          'REVENUE_CAT_GOOGLE_KEY',
          defaultValue: 'test_wyzkattJBBUIIymeWTHhZNZUwke',
        ),
      );

  Future<void> init() async {
    await Purchases.setLogLevel(kDebugMode ? LogLevel.debug : LogLevel.error);

    PurchasesConfiguration? configuration;
    if (Platform.isAndroid) {
      if (_apiKeyGoogle.startsWith('test_')) {
        debugPrint('[PurchaseService] WARNING: Using TEST key for Android');
            }
      configuration = PurchasesConfiguration(_apiKeyGoogle);
    } else if (Platform.isIOS) {
      if (_apiKeyApple.startsWith('test_')) {
        debugPrint('[PurchaseService] ERROR: Using TEST key for iOS. IAP will NOT work on real devices.');
      }
      configuration = PurchasesConfiguration(_apiKeyApple);
    }

    if (configuration != null) {
      await Purchases.configure(configuration);
      debugPrint('[PurchaseService] Configured with flavor: ${AppConfig.flavor.name}');
    }
  }

  Future<CustomerInfo> getCustomerInfo() async {
    return await Purchases.getCustomerInfo();
  }

  Future<Offerings?> getOfferings() async {
    try {
      return await Purchases.getOfferings();
    } catch (e) {
      debugPrint('[PurchaseService] Error fetching offerings: $e');
      return null;
    }
  }

  Future<void> logIn(String userId) async {
    try {
      await Purchases.logIn(userId);
    } catch (e) {
      debugPrint('[PurchaseService] Error logging in: $e');
    }
  }

  Future<void> logOut() async {
    await Purchases.logOut();
  }

  Future<bool> purchasePackage(Package package) async {
    try {
      final result = await Purchases.purchasePackage(package);
      return result.customerInfo.entitlements.active.isNotEmpty;
    } catch (e) {
      debugPrint('[PurchaseService] Error purchasing package: $e');
      return false;
    }
  }

  Future<bool> purchaseProduct(String productId) async {
    try {
      // For consumables (like extra storage)
      final result = await Purchases.purchaseProduct(productId);
      return result.customerInfo.allPurchasedProductIdentifiers.contains(productId);
    } catch (e) {
      debugPrint('[PurchaseService] Error purchasing product: $e');
      return false;
    }
  }

  Future<void> restorePurchases() async {
    await Purchases.restorePurchases();
  }
}
