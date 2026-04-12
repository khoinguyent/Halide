import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:purchases_flutter/purchases_flutter.dart' as rc;
import '../bloc/billing_bloc.dart';
import '../../../../core/providers/notification_provider.dart';
import '../../../../core/models/notification_model.dart';
import '../../../../core/utils/subscription_trial_text.dart';

class PaywallView extends ConsumerStatefulWidget {
  const PaywallView({Key? key}) : super(key: key);

  @override
  ConsumerState<PaywallView> createState() => _PaywallViewState();
}

class _PaywallViewState extends ConsumerState<PaywallView> {
  bool _isAnnual = true;
  int _selectedPlanIndex = 1; // Default to Pro Plan
  rc.Offerings? _cachedOfferings;
  bool _isPurchasing = false;
  late final BillingBloc _billingBloc;

  final Map<int, List<String>> _planFeatures = {
    0: [
      'Unlimited rolls and gear',
      'Fetch images from Lab Drive',
      'Personal cloud (Drive, NAS)',
      'Standard EXIF logging',
      'Basic roll management',
    ],
    1: [
      'Everything in Free',
      '5GB dedicated cloud storage',
      'Full Light Metering features',
      'Precision Scan Alignment',
      'Advanced AI metering advice',
      'Priority support access',
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
        backgroundColor: Colors.black,
        body: BlocConsumer<BillingBloc, BillingState>(
          listener: (context, state) {
            if (state is OfferingsLoaded) {
              _cachedOfferings = state.offerings;
              _isPurchasing = false;
            } else if (state is PurchaseSuccess) {
              if (_isPurchasing) {
                _isPurchasing = false;
                ref.read(notificationProvider.notifier).show(
                  'Welcome to Halide Premium! Your plan is now active.',
                  type: NotificationType.success,
                );
              }
              // Navigate to profile instead of just popping
              context.go('/profile');
            } else if (state is BillingError) {
              _isPurchasing = false;
              ref.read(notificationProvider.notifier).show(
                'Purchase could not be completed. Please try again.',
                type: NotificationType.error,
              );
              // Re-load offerings so button stays functional
              _billingBloc.add(LoadOfferings());
            } else if (state is BillingLoading) {
              // Only mark as purchasing if we already have offerings loaded
              if (_cachedOfferings != null) {
                _isPurchasing = true;
              }
            }
          },
          builder: (context, state) {
            final activeFeatures = _planFeatures[_selectedPlanIndex] ?? [];
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
                          Colors.black.withOpacity(0.3),
                          Colors.black.withOpacity(0.8),
                          Colors.black,
                        ],
                      ),
                    ),
                  ),
                ),
                // Content
                SafeArea(
                  child: Column(
                    children: [
                      // Close Button
                      Align(
                        alignment: Alignment.topRight,
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: IconButton(
                            icon: const Icon(Icons.close, color: Colors.white, size: 28),
                            onPressed: () => context.pop(),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Header
                      const Text(
                        'Choose Your Plan',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 32,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 40),
                        child: Text(
                          'Unlock professional gear tracking, cloud-syncing, and advanced light metering',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.7),
                            fontSize: 14,
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),
                      // Billing Toggle
                      _buildBillingToggle(),
                      const SizedBox(height: 40),
                      // Features Checklist
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 48),
                          child: SingleChildScrollView(
                            physics: const BouncingScrollPhysics(),
                            child: Column(
                              children: activeFeatures.map((f) => _buildFeatureItem(f)).toList(),
                            ),
                          ),
                        ),
                      ),
                      // Plan Selector
                      _buildPlanSelector(),
                      const SizedBox(height: 32),
                      // Subscribe Button
                      _buildSubscribeButton(),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
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
        color: Colors.black.withOpacity(0.5),
        borderRadius: BorderRadius.circular(25),
        border: Border.all(color: Colors.blue.withOpacity(0.3)),
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
                color: Colors.blue.withOpacity(0.8),
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
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.2),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: Colors.blue.withOpacity(0.5)),
            ),
            child: const Icon(Icons.check, color: Colors.blue, size: 18),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              feature,
              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500),
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
    return annual ? r'$39.99' : r'$3.99';
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
                width: (MediaQuery.of(context).size.width - 80) / 2,
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.blue.withOpacity(0.1) : Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isSelected ? Colors.blue : Colors.white.withOpacity(0.1),
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
                          color: Colors.green.withOpacity(0.8),
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
                        fontSize: 12,
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
                            fontSize: index == 0 ? 18 : 16,
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
                  ? [const Color(0xFF3B82F6), const Color(0xFF60A5FA)]
                  : [Colors.grey.shade800, Colors.grey.shade700],
            ),
            boxShadow: [
              BoxShadow(
                color: (isReady ? Colors.blue : Colors.grey).withOpacity(0.3),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ElevatedButton(
            onPressed: isReady
                ? () {
                    debugPrint('[Paywall] Purchase attempt: index=$_selectedPlanIndex, annual=$_isAnnual');
                    final specificOffering = offerings.all.values.firstWhere(
                      (o) => o.identifier.toLowerCase().contains('pro'),
                      orElse: () => offerings.current!,
                    );

                    final package = _isAnnual ? specificOffering.annual : specificOffering.monthly;
                    if (package != null) {
                      debugPrint('[Paywall] Purchasing package: ${package.identifier}');
                      _billingBloc.add(PurchasePackage(package));
                    } else {
                      debugPrint('[Paywall] No ${_isAnnual ? "annual" : "monthly"} package found for pro');
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
