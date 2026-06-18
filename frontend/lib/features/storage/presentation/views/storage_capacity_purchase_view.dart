import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:frontend/core/models/notification_model.dart';
import 'package:frontend/core/providers/notification_provider.dart';
import 'package:frontend/core/widgets/halide_scaffold.dart';
import 'package:frontend/features/billing/presentation/bloc/billing_bloc.dart';
import 'package:frontend/features/storage/domain/storage_addon_catalog.dart';
import 'package:frontend/providers/auth_provider.dart';
import 'package:frontend/providers/storage_accounts_refresh_provider.dart';
import 'package:frontend/services/purchase_service.dart';

/// Choose stackable System Cloud storage add-ons (+5 / +10 / +50 GB). Shown only after store prices load.
class StorageCapacityPurchaseView extends ConsumerStatefulWidget {
  const StorageCapacityPurchaseView({Key? key}) : super(key: key);

  @override
  ConsumerState<StorageCapacityPurchaseView> createState() =>
      _StorageCapacityPurchaseViewState();
}

class _StorageCapacityPurchaseViewState extends ConsumerState<StorageCapacityPurchaseView> {
  static const _zinc950 = Color(0xFF09090B);
  static const _orange500 = Color(0xFFF97316);

  late final BillingBloc _billingBloc;
  Map<String, StoreProduct> _productsById = {};
  Map<String, ProductDetails> _iapDetailsById = {};
  bool _loadingProducts = true;
  /// True only when every catalog SKU returned a store product (user never sees tier UI without prices).
  bool _productsReady = false;
  int _selectedIndex = 1;

  @override
  void initState() {
    super.initState();
    // Only [PurchaseStoreProduct] is used here — avoid [LoadOfferings] so we do not
    // flash the full-screen loader while subscription offerings load.
    _billingBloc = BillingBloc();
    _fetchStoreProducts();
  }

  @override
  void dispose() {
    _billingBloc.close();
    super.dispose();
  }

  bool _allCatalogProductsPresent(Map<String, StoreProduct> map) {
    for (final id in StorageAddonCatalog.allProductIds) {
      final p = map[id];
      if (p == null) return false;
      // Require a localized store price (RevenueCat / StoreKit); never show USD placeholders.
      if (p.priceString.trim().isEmpty) return false;
    }
    return map.isNotEmpty;
  }

  void _exitAfterLoadFailure({required bool isRefresh}) {
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final msg = isRefresh
          ? "We couldn't refresh prices. Please try again in a moment."
          : "We couldn't load storage options. Check your connection and try again.";
      ref.read(notificationProvider.notifier).show(
            msg,
            type: NotificationType.error,
          );
      if (context.canPop()) context.pop();
    });
  }

  Future<void> _fetchStoreProducts({bool isRefresh = false}) async {
    setState(() {
      _loadingProducts = true;
      _productsReady = false;
    });
    try {
      final list = await PurchaseService().getNonSubscriptionProducts(StorageAddonCatalog.allProductIds);
      final map = <String, StoreProduct>{};
      for (final p in list) {
        map[p.identifier] = p;
      }
      if (!mounted) return;

      if (!_allCatalogProductsPresent(map)) {
        setState(() {
          _productsById = {};
          _iapDetailsById = const {};
          _loadingProducts = false;
          _productsReady = false;
        });
        _exitAfterLoadFailure(isRefresh: isRefresh);
        return;
      }

      setState(() {
        _productsById = map;
      });

      if (Platform.isIOS || Platform.isAndroid) {
        await _queryIapProductDetails();
      }
      if (!mounted) return;

      setState(() {
        _loadingProducts = false;
        _productsReady = true;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _productsById = {};
        _iapDetailsById = const {};
        _loadingProducts = false;
        _productsReady = false;
      });
      _exitAfterLoadFailure(isRefresh: isRefresh);
    }
  }

  /// Same approach as [SubscriptionView]: localized price strings from StoreKit / Play Billing.
  Future<void> _queryIapProductDetails() async {
    final ids = StorageAddonCatalog.allProductIds.toSet();
    if (ids.isEmpty) return;

    try {
      final iap = InAppPurchase.instance;
      final available = await iap.isAvailable();
      if (!available) {
        if (mounted) setState(() => _iapDetailsById = const {});
        return;
      }
      final resp = await iap.queryProductDetails(ids);
      if (resp.error != null || resp.productDetails.isEmpty) {
        if (mounted) setState(() => _iapDetailsById = const {});
        return;
      }
      final map = <String, ProductDetails>{};
      for (final p in resp.productDetails) {
        map[p.id] = p;
      }
      if (mounted) setState(() => _iapDetailsById = map);
    } catch (_) {
      if (mounted) setState(() => _iapDetailsById = const {});
    }
  }

  /// Localized price from StoreKit / Play Billing, then RevenueCat. Never a hard-coded amount.
  String? _localizedPrice(StorageAddonTier tier) {
    final iap = _iapDetailsById[tier.productId];
    if (iap != null && iap.price.trim().isNotEmpty) return iap.price;
    final ps = _productsById[tier.productId]?.priceString;
    if (ps != null && ps.trim().isNotEmpty) return ps;
    return null;
  }

  String _priceLine(StorageAddonTier tier) => _localizedPrice(tier) ?? '—';

  StoreProduct? _selectedProduct() {
    final id = StorageAddonCatalog.tiers[_selectedIndex].productId;
    return _productsById[id];
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _billingBloc,
      child: BlocConsumer<BillingBloc, BillingState>(
        listener: (context, state) {
          if (state is PurchaseSuccess) {
            unawaited(Future(() async {
              ref.invalidate(userProfileProvider);
              try {
                await ref.read(userProfileProvider.future);
              } catch (_) {
                // Profile can still refresh on next screen via provider.
              }
              if (!context.mounted) return;
              ref.read(notificationProvider.notifier).show(
                    'Storage updated. Your new quota is active.',
                    type: NotificationType.success,
                  );
              ref.read(storageAccountsListVersionProvider.notifier).bump();
              if (context.canPop()) context.pop();
            }));
          } else if (state is PurchaseCancelled) {
            ref.read(notificationProvider.notifier).show(
                  'Purchase cancelled.',
                  type: NotificationType.info,
                );
          } else if (state is PurchaseFailed) {
            ref.read(notificationProvider.notifier).show(
                  state.message,
                  type: NotificationType.error,
                );
          }
        },
        builder: (context, state) {
          final purchasing = state is BillingLoading && _productsById.isNotEmpty;
          final tier = StorageAddonCatalog.tiers[_selectedIndex];
          final selectedPrice = _localizedPrice(tier);
          final canPurchase =
              _productsReady && !purchasing && selectedPrice != null;

          return HalideScaffold(
            backgroundColor: _zinc950,
            appBar: AppBar(
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => context.pop(),
                color: Colors.white,
              ),
              centerTitle: true,
              title: const Text(
                'ADD STORAGE',
                style: TextStyle(
                  letterSpacing: 2.0,
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                  color: Colors.white,
                ),
              ),
              backgroundColor: Colors.transparent,
              elevation: 0,
            ),
            child: Stack(
              children: [
                if (_productsReady)
                  SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Pick how much extra cloud space you need. Prices are shown in your '
                          'local currency. You can buy the same size more than once — each '
                          'purchase adds to your total.',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.65),
                            fontSize: 14,
                            height: 1.45,
                          ),
                        ),
                        const SizedBox(height: 22),
                        ...List.generate(StorageAddonCatalog.tiers.length, (i) {
                          final t = StorageAddonCatalog.tiers[i];
                          final selected = i == _selectedIndex;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _TierCard(
                              tier: t,
                              priceLine: _priceLine(t),
                              selected: selected,
                              onTap: () => setState(() => _selectedIndex = i),
                            ),
                          );
                        }),
                        const SizedBox(height: 20),
                        Text(
                          'Each pack adds to your vault total — you can buy the same size again anytime. '
                          'Payment uses the method on this device; extra space usually appears within a few moments.',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.45),
                            fontSize: 11,
                            height: 1.35,
                          ),
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: canPurchase
                                ? () {
                                    final p = _selectedProduct();
                                    if (p != null) {
                                      _billingBloc.add(PurchaseStoreProduct(p));
                                    }
                                  }
                                : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _orange500,
                              foregroundColor: Colors.white,
                              disabledBackgroundColor: _orange500.withOpacity(0.35),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              elevation: 0,
                            ),
                            child: Text(
                              selectedPrice == null
                                  ? 'BUY ${tier.shortLabel.toUpperCase()}'
                                  : 'Buy ${tier.shortLabel} — $selectedPrice',
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.8,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: purchasing ? null : () => _fetchStoreProducts(isRefresh: true),
                          child: Text(
                            'Refresh prices',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.55),
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                if (!_productsReady && _loadingProducts)
                  const Center(
                    child: CircularProgressIndicator(color: _orange500),
                  ),
                if (_productsReady && purchasing)
                  Positioned.fill(
                    child: Container(
                      color: _zinc950.withOpacity(0.55),
                      child: const Center(
                        child: CircularProgressIndicator(color: _orange500),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _TierCard extends StatelessWidget {
  final StorageAddonTier tier;
  final String priceLine;
  final bool selected;
  final VoidCallback onTap;

  const _TierCard({
    required this.tier,
    required this.priceLine,
    required this.selected,
    required this.onTap,
  });

  static const _orange500 = Color(0xFFF97316);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.06),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: selected ? _orange500 : Colors.white.withOpacity(0.12),
              width: selected ? 2 : 1,
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: _orange500.withOpacity(0.22),
                      blurRadius: 18,
                      spreadRadius: 0,
                    ),
                  ]
                : const [],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFA78BFA).withOpacity(0.18),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.auto_awesome, color: Color(0xFFA78BFA), size: 22),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          tier.shortLabel,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: _orange500.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(color: _orange500.withOpacity(0.55)),
                          ),
                          child: const Text(
                            'STACKABLE',
                            style: TextStyle(
                              color: _orange500,
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.6,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      tier.blurb,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.55),
                        fontSize: 13,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                priceLine,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
