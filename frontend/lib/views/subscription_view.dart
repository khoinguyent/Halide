import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:purchases_flutter/purchases_flutter.dart' as rc;
import 'package:url_launcher/url_launcher.dart';

import '../config/app_config.dart';
import '../core/models/notification_model.dart';
import '../core/providers/notification_provider.dart';
import '../core/utils/subscription_trial_text.dart';
import '../features/billing/presentation/bloc/billing_bloc.dart';
import '../providers/auth_provider.dart';
import '../services/purchase_service.dart';

class SubscriptionView extends ConsumerStatefulWidget {
  const SubscriptionView({Key? key}) : super(key: key);

  @override
  ConsumerState<SubscriptionView> createState() => _SubscriptionViewState();
}

class _SubscriptionViewState extends ConsumerState<SubscriptionView> {
  bool _isAnnual = true;
  int _selectedPlanIndex = 1; // Default to Pro Plan
  rc.Offerings? _cachedOfferings;
  bool _isPurchasing = false;
  bool _isRestoring = false;
  late final BillingBloc _billingBloc;

  // Branding / review compliance palette
  static const Color _zinc950 = Color(0xFF09090B);
  static const Color _zinc500 = Color(0xFF71717A);
  // Blue accents (match existing paywall button style)
  static const Color _blue600 = Color(0xFF2563EB);
  static const Color _blue400 = Color(0xFF60A5FA);
  static const double _contentMaxWidth = 520;

  // IAP reliability (StoreKit / Play Billing)
  bool _isQueryingProducts = false;
  bool _productQueryAttempted = false;
  String? _productQueryError;
  Map<String, ProductDetails> _productDetailsById = const {};

  /// Index 0 = Free (The Archive), 1 = Halide Pro. Plus-tier perks live in Free.
  final Map<int, List<String>> _planFeatures = {
    0: [
      'Roll & frame logging (aperture, shutter, location)',
      'Shooting → Lab → Scanned → Archived workflow',
      'Up to 3 cameras (1 lens each) & unlimited rolls',
      'Fetch images from Lab Drive',
      'Personal cloud sync (Google Drive, NAS)',
      'Standard EXIF logging',
    ],
    1: [
      'Everything in Free',
      'Halide Cloud Storage (hosted System Cloud)',
      'Professional light meter (spot metering & EV)',
      'Advanced exposure guidance',
      'Priority support',
    ],
  };

  @override
  void initState() {
    super.initState();
    _billingBloc = BillingBloc()..add(LoadOfferings());
  }

  @override
  void dispose() {
    _billingBloc.close();
    super.dispose();
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      ref.read(notificationProvider.notifier).show(
            'Could not open link.',
            type: NotificationType.error,
          );
    }
  }

  Future<void> _restorePurchases() async {
    if (_isRestoring) return;
    setState(() => _isRestoring = true);
    try {
      if (Platform.isIOS || Platform.isAndroid) {
        final iap = InAppPurchase.instance;
        if (await iap.isAvailable()) {
          await iap.restorePurchases();
        }
      }
      final info = await PurchaseService().restorePurchases();
      final restored = info.entitlements.active.isNotEmpty;
      ref.read(notificationProvider.notifier).show(
            restored ? 'Restored successfully.' : 'No previous purchases found.',
            type: restored ? NotificationType.success : NotificationType.info,
          );
      _billingBloc.add(LoadOfferings());
    } catch (e) {
      if (mounted) {
        ref.read(notificationProvider.notifier).show(
              'Restore could not be completed. Please try again.',
              type: NotificationType.error,
            );
      }
    } finally {
      if (mounted) setState(() => _isRestoring = false);
    }
  }

  Future<void> _queryProductDetailsForOfferings(rc.Offerings offerings) async {
    if (!Platform.isIOS && !Platform.isAndroid) return;

    final proOff = proOfferingFrom(offerings);
    final annualId = proOff?.annual?.storeProduct.identifier;
    final monthlyId = proOff?.monthly?.storeProduct.identifier;
    final ids = <String>{
      if (annualId != null && annualId.isNotEmpty) annualId,
      if (monthlyId != null && monthlyId.isNotEmpty) monthlyId,
    };
    if (ids.isEmpty) return;

    setState(() {
      _isQueryingProducts = true;
      _productQueryAttempted = true;
      _productQueryError = null;
    });

    try {
      final iap = InAppPurchase.instance;
      final available = await iap.isAvailable();
      if (!available) {
        setState(() {
          _productQueryError = 'Store is not available.';
          _productDetailsById = const {};
        });
        return;
      }

      final resp = await iap.queryProductDetails(ids);
      if (resp.error != null) {
        setState(() {
          _productQueryError = resp.error!.message;
          _productDetailsById = const {};
        });
        return;
      }

      final map = <String, ProductDetails>{};
      for (final p in resp.productDetails) {
        map[p.id] = p;
      }

      setState(() {
        _productDetailsById = map;
      });
    } catch (e) {
      setState(() {
        _productQueryError = e.toString();
        _productDetailsById = const {};
      });
    } finally {
      if (mounted) setState(() => _isQueryingProducts = false);
    }
  }

  String _selectedPriceForDisclosure() {
    final offerings = _cachedOfferings;
    if (offerings != null) {
      final proOff = proOfferingFrom(offerings);
      final pkg = _isAnnual ? proOff?.annual : proOff?.monthly;
      final id = pkg?.storeProduct.identifier;
      final pd = id == null ? null : _productDetailsById[id];
      if (pd != null) return pd.price;

      final ps = pkg?.storeProduct.priceString;
      if (ps != null && ps.isNotEmpty) return ps;
    }
    return r'$--';
  }

  Widget _subscriptionDisclosureBlock() {
    final price = _selectedPriceForDisclosure();
    final suffix = _isAnnual ? '/yr' : '/month';
    const text =
        'A [PRICE] subscription will be applied to your iTunes account on confirmation. '
        'Subscriptions will automatically renew unless canceled within 24-hours before the end of the current period. '
        'Manage anytime in iTunes settings. Any unused portion of a free trial will be forfeited if you purchase a subscription.';

    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 4, 32, 0),
      child: Text(
        text.replaceFirst('[PRICE]', '$price$suffix'),
        textAlign: TextAlign.center,
        style: TextStyle(
          color: _zinc500.withValues(alpha: 0.9),
          fontSize: 10,
          height: 1.25,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _legalFooter() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
      child: Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 8,
        runSpacing: 4,
        children: [
          TextButton(
            onPressed: () => _openUrl(AppConfig.privacyPolicyWebUrl),
            style: TextButton.styleFrom(
              foregroundColor: _zinc500,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              'Privacy Policy',
              style: TextStyle(
                color: _zinc500,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                decoration: TextDecoration.underline,
                decorationColor: _zinc500,
              ),
            ),
          ),
          Text('·', style: TextStyle(color: _zinc500.withValues(alpha: 0.6), fontSize: 12)),
          TextButton(
            onPressed: () => _openUrl(AppConfig.appleStandardEulaUrl),
            style: TextButton.styleFrom(
              foregroundColor: _zinc500,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              'Terms of Use',
              style: TextStyle(
                color: _zinc500,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                decoration: TextDecoration.underline,
                decorationColor: _zinc500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Shown under Pro pricing; uses StoreKit/Play intro offer when loaded.
  String? _proTrialFooterLine() {
    final offerings = _cachedOfferings;
    if (offerings == null) return null;
    final pkg = proPackageForSelection(offerings, annual: _isAnnual);
    if (pkg == null) return null;
    return introOfferShortLabel(pkg.storeProduct);
  }

  String _subscribeButtonLabel(rc.Offerings? offerings) {
    final pkg = offerings == null
        ? null
        : proPackageForSelection(offerings, annual: _isAnnual);
    final intro = pkg?.storeProduct.introductoryPrice;
    final freeTrial = intro != null && intro.price <= 0.001;
    if (freeTrial) return 'Start free trial';
    return 'Get Halide Pro';
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _billingBloc,
      child: Scaffold(
        backgroundColor: _zinc950,
        body: BlocConsumer<BillingBloc, BillingState>(
          listener: (context, state) {
            if (state is OfferingsLoaded) {
              _cachedOfferings = state.offerings;
              _isPurchasing = false;
              // Load StoreKit product details for reliability & disclosure text.
              _queryProductDetailsForOfferings(state.offerings);
            } else if (state is PurchaseSuccess) {
              if (_isPurchasing) {
                _isPurchasing = false;
                ref.read(notificationProvider.notifier).show(
                  'Welcome to Halide Pro! Your plan is now active.',
                  type: NotificationType.success,
                );
              }
              ref.invalidate(userProfileProvider);
              // Navigate to profile instead of just popping
              context.go('/profile');
            } else if (state is PurchaseCancelled) {
              // User cancelled the purchase sheet. This is not an error.
              _isPurchasing = false;
              _billingBloc.add(LoadOfferings());
            } else if (state is PurchaseFailed) {
              _isPurchasing = false;
              ref.read(notificationProvider.notifier).show(
                'Purchase could not be completed. Please try again.',
                type: NotificationType.error,
              );
              // Re-load offerings so button stays functional
              _billingBloc.add(LoadOfferings());
            } else if (state is OfferingsLoadFailed) {
              _isPurchasing = false;
              ref.read(notificationProvider.notifier).show(
                'Unable to load subscription options. Please try again.',
                type: NotificationType.error,
              );
            } else if (state is BillingLoading) {
              // Only mark as purchasing if we already have offerings loaded
              if (_cachedOfferings != null) {
                _isPurchasing = true;
              }
            }
          },
          builder: (context, state) {
            final activeFeatures = _planFeatures[_selectedPlanIndex] ?? [];
            final bool offeringsLoading =
                _cachedOfferings == null && (state is BillingLoading || state is BillingInitial);
            final bool showProductSpinner = offeringsLoading || _isQueryingProducts;
            final bool productEmptyAfterAttempt =
                _productQueryAttempted && _productDetailsById.isEmpty && _productQueryError == null;
            return Stack(
              children: [
                // Background Image
                Positioned.fill(
                  child: Image.asset(
                    'assets/images/paywall_bg.png',
                    fit: BoxFit.cover,
                  ),
                ),
                // Gradient Overlay
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          _zinc950.withOpacity(0.4),
                          _zinc950.withOpacity(0.85),
                          _zinc950,
                        ],
                      ),
                    ),
                  ),
                ),
                // Content
                SafeArea(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final maxWidth = constraints.maxWidth;
                      final contentWidth = maxWidth > _contentMaxWidth ? _contentMaxWidth : maxWidth;

                      return Align(
                        alignment: Alignment.topCenter,
                        child: SizedBox(
                          width: contentWidth,
                          child: Column(
                            children: [
                              // Close Button
                              Align(
                                alignment: Alignment.topRight,
                                child: Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: IconButton(
                                    icon: const Icon(Icons.close, color: Colors.white, size: 24),
                                    onPressed: () => context.pop(),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 4),
                              // Header
                              const Text(
                                'Choose Your Plan',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 26,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 28),
                                child: Text(
                                  'Pro adds Halide Cloud Storage and the professional light meter',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.7),
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 14),
                              // Billing Toggle + Plans
                              _buildBillingToggle(),
                              const SizedBox(height: 14),
                              _buildPlanSelector(),
                              const SizedBox(height: 14),
                              // Features Checklist
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 24),
                                  child: SingleChildScrollView(
                                    physics: const BouncingScrollPhysics(),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.stretch,
                                      children: activeFeatures.map((f) => _buildFeatureItem(f)).toList(),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              // Subscribe Button
                              _buildSubscribeButton(),
                              if (_selectedPlanIndex != 0) ...[
                                const SizedBox(height: 10),
                                _subscriptionDisclosureBlock(),
                                if (productEmptyAfterAttempt)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 8),
                                    child: TextButton(
                                      onPressed: () {
                                        final o = _cachedOfferings;
                                        if (o != null) _queryProductDetailsForOfferings(o);
                                      },
                                      child: const Text(
                                        'Retry',
                                        style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w700),
                                      ),
                                    ),
                                  ),
                              ],
                              _buildRestoreRow(),
                              _legalFooter(),
                              const SizedBox(height: 10),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                if (showProductSpinner)
                  Positioned.fill(
                    child: Container(
                      color: _zinc950.withOpacity(0.65),
                      child: const Center(
                        child: CircularProgressIndicator(color: Colors.white),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildRestoreRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextButton(
            onPressed: (_isRestoring || _isPurchasing) ? null : _restorePurchases,
            child: _isRestoring
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white70,
                    ),
                  )
                : Text(
                    'Restore Purchases',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.75),
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              'You may be asked to sign in with your Apple ID to restore purchases.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _zinc500,
                fontSize: 10,
                height: 1.2,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBillingToggle() {
    // Hide toggle for Free plan
    if (_selectedPlanIndex == 0) {
      return const SizedBox(height: 50);
    }

    return Container(
      width: 280,
      height: 50,
      decoration: BoxDecoration(
        color: _zinc950.withOpacity(0.45),
        borderRadius: BorderRadius.circular(25),
        border: Border.all(color: _blue400.withOpacity(0.35)),
      ),
      child: Stack(
        children: [
          AnimatedAlign(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOut,
            alignment: _isAnnual ? Alignment.centerRight : Alignment.centerLeft,
            child: Container(
              width: 140,
              height: 50,
              decoration: BoxDecoration(
                color: _blue600.withOpacity(0.85),
                borderRadius: BorderRadius.circular(25),
              ),
            ),
          ),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _isAnnual = false),
                  child: Center(
                    child: Text(
                      'Monthly billing',
                      style: TextStyle(
                        color: _isAnnual ? Colors.white70 : Colors.white,
                        fontWeight: _isAnnual ? FontWeight.normal : FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _isAnnual = true),
                  child: Center(
                    child: Text(
                      'Annual billing',
                      style: TextStyle(
                        color: _isAnnual ? Colors.white : Colors.white70,
                        fontWeight: _isAnnual ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureItem(String feature) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: _blue400.withOpacity(0.18),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: _blue400.withOpacity(0.5)),
            ),
            child: const Icon(Icons.check, color: _blue400, size: 18),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              feature,
              style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  /// Shown on the Pro card. Uses App Store / Play prices from RevenueCat when offerings load.
  String _proPriceLabel({required bool annual}) {
    final o = _cachedOfferings;
    if (o != null) {
      final off = proOfferingFrom(o);
      final pkg = annual ? off?.annual : off?.monthly;
      final ps = pkg?.storeProduct.priceString;
      if (ps != null && ps.isNotEmpty) return ps;
    }
    return annual ? r'$59.99' : r'$5.99';
  }

  Widget _buildPlanSelector() {
    final plans = [
      {'name': 'Free', 'monthly': '0', 'annual': '0'},
      {
        'name': 'Pro',
        'monthly': _proPriceLabel(annual: false),
        'annual': _proPriceLabel(annual: true),
      },
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(plans.length, (index) {
          final isSelected = _selectedPlanIndex == index;
          final plan = plans[index];
          
          String displayPrice = _isAnnual ? plan['annual']! : plan['monthly']!;
          String duration = _isAnnual ? '/yr' : '/mo';
          if (index == 0) duration = '';

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: GestureDetector(
              onTap: () => setState(() => _selectedPlanIndex = index),
              child: Container(
                width: 150,
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: isSelected ? _blue600.withOpacity(0.12) : Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isSelected ? _blue400 : Colors.white.withOpacity(0.1),
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Column(
                  children: [
                    if (_isAnnual && index > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        margin: const EdgeInsets.only(bottom: 4),
                        decoration: BoxDecoration(
                          color: _blue600.withOpacity(0.85),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'SAVE 20%',
                          style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
                        ),
                      ),
                    Text(
                      plan['name']!,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.7),
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          index == 0 ? 'Free' : displayPrice,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: index == 0 ? 17 : 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(duration, style: const TextStyle(color: Colors.white54, fontSize: 10)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      index == 0
                          ? 'Forever'
                          : (_proTrialFooterLine() ?? 'Free trial where eligible'),
                      style: const TextStyle(color: Colors.white54, fontSize: 9),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildSubscribeButton() {
    if (_selectedPlanIndex == 0) return const SizedBox(height: 60);

    final offerings = _cachedOfferings;
    final bool isReady = offerings != null && !_isPurchasing;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: SizedBox(
        width: double.infinity,
        height: 60,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(30),
            gradient: LinearGradient(
              colors: isReady
                  ? [_blue600, _blue400]
                  : [Colors.grey.shade800, Colors.grey.shade700],
            ),
            boxShadow: [
              BoxShadow(
                color: (isReady ? _blue600 : Colors.grey).withOpacity(0.3),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ElevatedButton(
            onPressed: isReady
                ? () {
                    debugPrint('[Subscription] Purchase attempt: index=$_selectedPlanIndex, annual=$_isAnnual');
                    final specificOffering = offerings.all.values.firstWhere(
                      (o) => o.identifier.toLowerCase().contains('pro'),
                      orElse: () => offerings.current!,
                    );

                    final package = _isAnnual ? specificOffering.annual : specificOffering.monthly;
                    if (package != null) {
                      debugPrint('[Subscription] Purchasing package: ${package.identifier}');
                      _billingBloc.add(PurchasePackage(package));
                    } else {
                      debugPrint('[Subscription] No ${_isAnnual ? "annual" : "monthly"} package found for pro');
                      ref.read(notificationProvider.notifier).show(
                        'This plan is not available yet. Please try another option.',
                        type: NotificationType.warning,
                      );
                    }
                  }
                : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              disabledBackgroundColor: Colors.transparent,
              shadowColor: Colors.transparent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
            ),
            child: _isPurchasing
                ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3))
                : Text(
                    _subscribeButtonLabel(offerings),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
