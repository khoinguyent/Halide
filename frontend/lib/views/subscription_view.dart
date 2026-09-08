import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:purchases_flutter/purchases_flutter.dart' as rc;
import 'package:url_launcher/url_launcher.dart';

import '../config/app_config.dart';
import '../core/l10n/l10n_extension.dart';
import '../core/models/notification_model.dart';
import '../l10n/app_localizations.dart';
import '../core/providers/notification_provider.dart';
import '../core/utils/subscription_trial_text.dart';
import '../features/billing/presentation/bloc/billing_bloc.dart';
import '../providers/auth_provider.dart';
import '../providers/profile_provider.dart';
import '../services/api_service.dart';
import '../services/purchase_service.dart';

class SubscriptionView extends ConsumerStatefulWidget {
  /// When true (first launch / trial gate): hide Free plan, default Pro,
  /// require monthly/annual choice before starting the intro trial.
  final bool forceTrialChoice;

  const SubscriptionView({Key? key, this.forceTrialChoice = false}) : super(key: key);

  @override
  ConsumerState<SubscriptionView> createState() => _SubscriptionViewState();
}

class _SubscriptionViewState extends ConsumerState<SubscriptionView> {
  late bool _isAnnual;
  late int _selectedPlanIndex;
  rc.Offerings? _cachedOfferings;
  bool _isPurchasing = false;
  bool _isRestoring = false;
  bool _markedOnboarding = false;
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

  List<String> _planFeatures(AppLocalizations l10n, int planIndex) {
    if (planIndex == 0) {
      return [
        l10n.freeFeature1,
        l10n.freeFeature2,
        l10n.freeFeature3,
        l10n.freeFeature4,
        l10n.freeFeature5,
        l10n.freeFeature6,
      ];
    }
    return [
      l10n.proFeature1,
      l10n.proFeature2,
      l10n.proFeature3,
      l10n.proFeature4,
      l10n.proFeature5,
    ];
  }

  @override
  void initState() {
    super.initState();
    // Trial gate: Pro + monthly only (3-day intro lives on monthly in ASC).
    // Normal paywall defaults to Pro + annual.
    _selectedPlanIndex = 1;
    _isAnnual = !widget.forceTrialChoice;
    _billingBloc = BillingBloc()..add(LoadOfferings());
  }

  /// First-launch trial always purchases monthly, regardless of UI state.
  bool get _purchaseAnnual => widget.forceTrialChoice ? false : _isAnnual;

  Future<void> _markOnboardingSeenIfNeeded() async {
    if (_markedOnboarding || !widget.forceTrialChoice) return;
    _markedOnboarding = true;
    try {
      await ref.read(profileServiceProvider).markOnboardingSeen();
      ref.invalidate(userProfileProvider);
    } catch (_) {
      // Best-effort; user can still use the app.
    }
  }

  Future<void> _dismissPaywall() async {
    await _markOnboardingSeenIfNeeded();
    if (mounted) context.pop();
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
            context.l10n.couldNotOpenLink,
            type: NotificationType.error,
          );
    }
  }

  /// Restore StoreKit/Play purchases via RevenueCat, then reconcile Postgres
  /// (`POST /billing/sync?force_remote=true`) so Drive sync and other Pro gates match the SDK.
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
      final activeIds = info.entitlements.active.keys.toList();
      final restoredLocally = activeIds.isNotEmpty;

      ref
          .read(localEntitlementPlanProvider.notifier)
          .updateFromActiveEntitlementIds(activeIds);

      // Push RevenueCat REST → Postgres (same path as post-purchase).
      String? syncedTier;
      Object? syncError;
      final api = ApiService();
      for (var attempt = 0; attempt < 3; attempt++) {
        if (attempt > 0) {
          await Future<void>.delayed(
            Duration(milliseconds: attempt == 1 ? 700 : 900),
          );
        }
        try {
          final res = await api.post('/api/v1/billing/sync?force_remote=true');
          final data = res.data;
          if (data is Map) {
            syncedTier = data['tier']?.toString();
          }
          syncError = null;
          break;
        } catch (e) {
          syncError = e;
          // ignore: avoid_print
          print('[Subscription] billing/sync after restore attempt ${attempt + 1}: $e');
        }
      }

      ref.invalidate(userProfileProvider);

      if (!mounted) return;
      final l10n = context.l10n;
      final backendPro = (syncedTier ?? '').toLowerCase() == 'pro';
      if (restoredLocally || backendPro) {
        ref.read(notificationProvider.notifier).show(
              l10n.restoredSuccessfully,
              type: NotificationType.success,
            );
      } else if (syncError != null && !restoredLocally) {
        ref.read(notificationProvider.notifier).show(
              l10n.restoreFailed,
              type: NotificationType.error,
            );
      } else {
        ref.read(notificationProvider.notifier).show(
              l10n.noPreviousPurchases,
              type: NotificationType.info,
            );
      }
      _billingBloc.add(LoadOfferings());
    } catch (e) {
      if (mounted) {
        ref.read(notificationProvider.notifier).show(
              context.l10n.restoreFailed,
              type: NotificationType.error,
            );
      }
    } finally {
      if (mounted) setState(() => _isRestoring = false);
    }
  }

  Future<void> _queryProductDetailsForOfferings(rc.Offerings offerings) async {
    if (!Platform.isIOS && !Platform.isAndroid) return;
    final l10n = context.l10n;

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
          _productQueryError = l10n.storeNotAvailable;
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
      final pkg = _purchaseAnnual ? proOff?.annual : proOff?.monthly;
      final id = pkg?.storeProduct.identifier;
      final pd = id == null ? null : _productDetailsById[id];
      if (pd != null) return pd.price;

      final ps = pkg?.storeProduct.priceString;
      if (ps != null && ps.isNotEmpty) return ps;
    }
    return r'$--';
  }

  Widget _subscriptionDisclosureBlock(AppLocalizations l10n) {
    final price = _selectedPriceForDisclosure();
    final suffix = _purchaseAnnual ? l10n.perYearShort : l10n.perMonthShort;

    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 4, 32, 0),
      child: Text(
        l10n.subscriptionDisclosure('$price$suffix'),
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

  Widget _legalFooter(AppLocalizations l10n) {
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
              l10n.privacyPolicyLink,
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
              l10n.termsOfUse,
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
    final pkg = proPackageForSelection(offerings, annual: _purchaseAnnual);
    if (pkg == null) return null;
    return introOfferShortLabel(pkg.storeProduct);
  }

  String _subscribeButtonLabel(AppLocalizations l10n, rc.Offerings? offerings) {
    final pkg = offerings == null
        ? null
        : proPackageForSelection(offerings, annual: _purchaseAnnual);
    final intro = pkg?.storeProduct.introductoryPrice;
    final freeTrial = intro != null && intro.price <= 0.001;
    if (freeTrial || widget.forceTrialChoice) return l10n.startFreeTrial;
    return l10n.getHalidePro;
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _billingBloc,
      child: Scaffold(
        backgroundColor: _zinc950,
        body: BlocConsumer<BillingBloc, BillingState>(
          listener: (context, state) {
            final l10n = context.l10n;
            if (state is OfferingsLoaded) {
              _cachedOfferings = state.offerings;
              _isPurchasing = false;
              // Load StoreKit product details for reliability & disclosure text.
              _queryProductDetailsForOfferings(state.offerings);
            } else if (state is PurchaseSuccess) {
              if (_isPurchasing) {
                _isPurchasing = false;
                ref.read(notificationProvider.notifier).show(
                  l10n.welcomeToHalidePro,
                  type: NotificationType.success,
                );
              }
              unawaited(_markOnboardingSeenIfNeeded());
              ref.invalidate(userProfileProvider);
              // Navigate to profile instead of just popping
              context.go('/profile');
            } else if (state is RestoreCompleted) {
              _isPurchasing = false;
              _isRestoring = false;
              ref.invalidate(userProfileProvider);
            } else if (state is PurchaseCancelled) {
              // User cancelled the purchase sheet. This is not an error.
              _isPurchasing = false;
              _billingBloc.add(LoadOfferings());
            } else if (state is PurchaseFailed) {
              _isPurchasing = false;
              ref.read(notificationProvider.notifier).show(
                l10n.purchaseFailedRetry,
                type: NotificationType.error,
              );
              // Re-load offerings so button stays functional
              _billingBloc.add(LoadOfferings());
            } else if (state is OfferingsLoadFailed) {
              _isPurchasing = false;
              ref.read(notificationProvider.notifier).show(
                l10n.unableToLoadSubscription,
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
            final l10n = context.l10n;
            final activeFeatures = _planFeatures(l10n, _selectedPlanIndex);
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
                                    onPressed: () => unawaited(_dismissPaywall()),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 4),
                              // Header
                              Text(
                                l10n.chooseYourPlan,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 26,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 28),
                                child: Text(
                                  widget.forceTrialChoice
                                      ? '${l10n.startFreeTrial} · ${l10n.monthlyBilling}'
                                      : l10n.paywallSubtitle,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.7),
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 14),
                              // Trial gate: monthly only (no annual toggle).
                              if (!widget.forceTrialChoice) ...[
                                _buildBillingToggle(l10n),
                                const SizedBox(height: 14),
                              ],
                              _buildPlanSelector(l10n),
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
                              _buildSubscribeButton(l10n),
                              if (_selectedPlanIndex != 0) ...[
                                const SizedBox(height: 10),
                                _subscriptionDisclosureBlock(l10n),
                                if (productEmptyAfterAttempt)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 8),
                                    child: TextButton(
                                      onPressed: () {
                                        final o = _cachedOfferings;
                                        if (o != null) _queryProductDetailsForOfferings(o);
                                      },
                                      child: Text(
                                        l10n.retry,
                                        style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w700),
                                      ),
                                    ),
                                  ),
                              ],
                              _buildRestoreRow(l10n),
                              _legalFooter(l10n),
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

  Widget _buildRestoreRow(AppLocalizations l10n) {
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
                    l10n.restorePurchases,
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
              l10n.restoreAppleIdHint,
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

  Widget _buildBillingToggle(AppLocalizations l10n) {
    // Hide toggle for Free plan
    if (_selectedPlanIndex == 0) {
      return const SizedBox(height: 50);
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final toggleWidth = constraints.maxWidth > 0
            ? constraints.maxWidth.clamp(280.0, 340.0)
            : 300.0;
        final segmentWidth = toggleWidth / 2;

        return Container(
          width: toggleWidth,
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
                  width: segmentWidth,
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
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          child: Text(
                            l10n.monthly,
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: _isAnnual ? Colors.white70 : Colors.white,
                              fontSize: 12,
                              fontWeight: _isAnnual ? FontWeight.normal : FontWeight.bold,
                              height: 1.1,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _isAnnual = true),
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          child: Text(
                            l10n.annual,
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: _isAnnual ? Colors.white : Colors.white70,
                              fontSize: 12,
                              fontWeight: _isAnnual ? FontWeight.bold : FontWeight.normal,
                              height: 1.1,
                            ),
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
      },
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
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
                height: 1.25,
              ),
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

  Widget _buildPlanSelector(AppLocalizations l10n) {
    final plans = [
      if (!widget.forceTrialChoice)
        {'name': l10n.freePlanName, 'monthly': '0', 'annual': '0'},
      {
        'name': l10n.proPlanName,
        'monthly': _proPriceLabel(annual: false),
        'annual': _proPriceLabel(annual: true),
      },
    ];
    // When Free is hidden, Pro is at index 0 in [plans] but [_selectedPlanIndex] stays 1.
    final planUiIndexOffset = widget.forceTrialChoice ? 1 : 0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(plans.length, (index) {
          final planIndex = index + planUiIndexOffset;
          final isSelected = _selectedPlanIndex == planIndex;
          final plan = plans[index];
          
          String displayPrice = _purchaseAnnual ? plan['annual']! : plan['monthly']!;
          String duration = _purchaseAnnual ? l10n.perYearShort : l10n.perMonthShort;
          if (planIndex == 0) duration = '';

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: GestureDetector(
              onTap: () => setState(() => _selectedPlanIndex = planIndex),
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
                    if (_purchaseAnnual && planIndex > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        margin: const EdgeInsets.only(bottom: 4),
                        decoration: BoxDecoration(
                          color: _blue600.withOpacity(0.85),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          l10n.save20Percent,
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
                          planIndex == 0 ? l10n.free : displayPrice,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: planIndex == 0 ? 17 : 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(duration, style: const TextStyle(color: Colors.white54, fontSize: 10)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      planIndex == 0
                          ? l10n.forever
                          : (_proTrialFooterLine() ?? l10n.freeTrialWhereEligible),
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

  Widget _buildSubscribeButton(AppLocalizations l10n) {
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
                    debugPrint(
                      '[Subscription] Purchase attempt: index=$_selectedPlanIndex, annual=$_purchaseAnnual, forceTrial=${widget.forceTrialChoice}',
                    );
                    final specificOffering = offerings.all.values.firstWhere(
                      (o) => o.identifier.toLowerCase().contains('pro'),
                      orElse: () => offerings.current!,
                    );

                    final package =
                        _purchaseAnnual ? specificOffering.annual : specificOffering.monthly;
                    if (package != null) {
                      debugPrint('[Subscription] Purchasing package: ${package.identifier}');
                      _billingBloc.add(PurchasePackage(package));
                    } else {
                      debugPrint(
                        '[Subscription] No ${_purchaseAnnual ? "annual" : "monthly"} package found for pro',
                      );
                      ref.read(notificationProvider.notifier).show(
                        l10n.planNotAvailable,
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
                    _subscribeButtonLabel(l10n, offerings),
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
