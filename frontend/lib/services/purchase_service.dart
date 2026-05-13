import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:flutter/services.dart';
import '../config/app_config.dart';
import '../config/env_loader.dart';

enum PurchaseOutcome {
  success,
  cancelled,
  error,
}

class PurchaseResult {
  const PurchaseResult(this.outcome, {this.message});
  final PurchaseOutcome outcome;
  final String? message;
}

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

  /// Non-subscription IAPs (consumables + non-consumables). On Android use [ProductCategory.nonSubscription].
  Future<List<StoreProduct>> getNonSubscriptionProducts(List<String> productIds) async {
    if (productIds.isEmpty) return [];
    try {
      return await Purchases.getProducts(
        productIds,
        productCategory: ProductCategory.nonSubscription,
      );
    } catch (e) {
      debugPrint('[PurchaseService] Error fetching non-subscription products: $e');
      return [];
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

  Future<PurchaseResult> purchasePackage(Package package) async {
    try {
      final result = await Purchases.purchasePackage(package);
      final active = result.customerInfo.entitlements.active.isNotEmpty;
      return PurchaseResult(active ? PurchaseOutcome.success : PurchaseOutcome.error);
    } on PlatformException catch (e) {
      final code = PurchasesErrorHelper.getErrorCode(e);
      if (code == PurchasesErrorCode.purchaseCancelledError) {
        return const PurchaseResult(PurchaseOutcome.cancelled);
      }
      debugPrint('[PurchaseService] Error purchasing package: $e');
      return PurchaseResult(PurchaseOutcome.error, message: e.message);
    } catch (e) {
      debugPrint('[PurchaseService] Error purchasing package: $e');
      return PurchaseResult(PurchaseOutcome.error, message: e.toString());
    }
  }

  Future<PurchaseResult> purchaseProduct(String productId) async {
    try {
      // For consumables (like extra storage)
      final result = await Purchases.purchaseProduct(productId);
      final purchased = result.customerInfo.allPurchasedProductIdentifiers.contains(productId);
      return PurchaseResult(purchased ? PurchaseOutcome.success : PurchaseOutcome.error);
    } on PlatformException catch (e) {
      final code = PurchasesErrorHelper.getErrorCode(e);
      if (code == PurchasesErrorCode.purchaseCancelledError) {
        return const PurchaseResult(PurchaseOutcome.cancelled);
      }
      debugPrint('[PurchaseService] Error purchasing product: $e');
      return PurchaseResult(PurchaseOutcome.error, message: e.message);
    } catch (e) {
      debugPrint('[PurchaseService] Error purchasing product: $e');
      return PurchaseResult(PurchaseOutcome.error, message: e.toString());
    }
  }

  /// Preferred for one-time / non-subscription products loaded via [getNonSubscriptionProducts].
  /// Consumables may not appear in [CustomerInfo.allPurchasedProductIdentifiers]; any non-cancelled
  /// completion from RevenueCat is treated as success (backend reconciles via /billing/sync).
  Future<PurchaseResult> purchaseStoreProduct(StoreProduct product) async {
    try {
      await Purchases.purchaseStoreProduct(product);
      return const PurchaseResult(PurchaseOutcome.success);
    } on PlatformException catch (e) {
      final code = PurchasesErrorHelper.getErrorCode(e);
      if (code == PurchasesErrorCode.purchaseCancelledError) {
        return const PurchaseResult(PurchaseOutcome.cancelled);
      }
      debugPrint('[PurchaseService] Error purchasing store product: $e');
      return PurchaseResult(PurchaseOutcome.error, message: e.message);
    } catch (e) {
      debugPrint('[PurchaseService] Error purchasing store product: $e');
      return PurchaseResult(PurchaseOutcome.error, message: e.toString());
    }
  }

  Future<CustomerInfo> restorePurchases() async {
    return await Purchases.restorePurchases();
  }
}
