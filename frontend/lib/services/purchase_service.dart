import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

class PurchaseService {
  static final PurchaseService _instance = PurchaseService._internal();
  factory PurchaseService() => _instance;
  PurchaseService._internal();

  // RevenueCat Test Keys from Dashboard
  static const _apiKeyApple = 'test_wyzkattJBBUIIymeWTHhZNZUwke';
  static const _apiKeyGoogle = 'test_wyzkattJBBUIIymeWTHhZNZUwke';

  Future<void> init() async {
    await Purchases.setLogLevel(kDebugMode ? LogLevel.debug : LogLevel.error);

    PurchasesConfiguration? configuration;
    if (Platform.isAndroid) {
      configuration = PurchasesConfiguration(_apiKeyGoogle);
    } else if (Platform.isIOS) {
      configuration = PurchasesConfiguration(_apiKeyApple);
    }

    if (configuration != null) {
      await Purchases.configure(configuration);
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
    await Purchases.logIn(userId);
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
