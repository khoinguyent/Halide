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

/// Choose stackable System Cloud storage add-ons (5 / 10 / 50 GB). Prices from the store (localized).
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
  String? _productLoadNote;
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

  Future<void> _fetchStoreProducts() async {
    setState(() {
      _loadingProducts = true;
      _productLoadNote = null;
    });
    try {
      final list = await PurchaseService().getNonSubscriptionProducts(StorageAddonCatalog.allProductIds);
      final map = <String, StoreProduct>{};
      for (final p in list) {
        map[p.identifier] = p;
      }
      if (mounted) {
        setState(() {
          _productsById = map;
          if (map.isEmpty) {
            _productLoadNote =
                'Store products are not available yet. Confirm consumable IAPs in App Store Connect and RevenueCat, then try again.';
          }
        });
      }
      if (Platform.isIOS || Platform.isAndroid) {
        await _queryIapProductDetails();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _productsById = {};
          _productLoadNote = 'Could not load products. Check your RevenueCat and store configuration.';
        });
      }
    } finally {
      if (mounted) setState(() => _loadingProducts = false);
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

  String _priceLine(StorageAddonTier tier) {
    final iap = _iapDetailsById[tier.productId];
    if (iap != null && iap.price.isNotEmpty) return iap.price;
    final p = _productsById[tier.productId];
    final ps = p?.priceString;
    if (ps != null && ps.isNotEmpty) return ps;
    return tier.guidePriceUsd;
  }

  StoreProduct? _selectedProduct() {
    final id = StorageAddonCatalog.tiers[_selectedIndex].productId;
    return _productsById[id];
  }

  @override
  Widget build(BuildContext context) {
    final tier = StorageAddonCatalog.tiers[_selectedIndex];

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
          final product = _selectedProduct();
          final canPurchase = product != null && !purchasing;

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
                SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Choose how much System Cloud space to add. '
                        'Prices follow your App Store / Play country (same as the subscription paywall). '
                        'You can buy the same pack again; each purchase increases your quota.',
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
                      if (_productLoadNote != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          _productLoadNote!,
                          style: TextStyle(
                            color: Colors.amber.withOpacity(0.85),
                            fontSize: 12,
                            height: 1.4,
                          ),
                        ),
                      ],
                      const SizedBox(height: 20),
                      Text(
                        'Consumable in-app purchase. After you buy, the app syncs billing with '
                        'your server (and retries briefly) so your quota updates before you return.',
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
                            product == null
                                ? 'CONFIGURE STORE PRODUCTS'
                                : 'BUY ${tier.shortLabel.toUpperCase()} — ${_priceLine(tier).toUpperCase()}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.8,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: purchasing ? null : _fetchStoreProducts,
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
                if (purchasing || _loadingProducts)
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
