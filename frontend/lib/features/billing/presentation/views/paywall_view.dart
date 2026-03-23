import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:purchases_flutter/purchases_flutter.dart' as rc;
import '../../../../core/widgets/glass_panel.dart';
import '../../../../core/widgets/halide_scaffold.dart';
import '../bloc/billing_bloc.dart';
import 'package:frontend/features/billing/models/plan_model.dart';

class PaywallView extends StatefulWidget {
  const PaywallView({Key? key}) : super(key: key);

  @override
  State<PaywallView> createState() => _PaywallViewState();
}

class _PaywallViewState extends State<PaywallView> {
  bool _isProMode = true; // Default to Pro
  final PageController _pageController = PageController(viewportFraction: 0.85, initialPage: 2); 
  int _currentPage = 2;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentPlans = _isProMode ? proPlans : plusPlans;

    return BlocProvider(
      create: (context) => BillingBloc()..add(LoadOfferings()),
      child: HalideScaffold(
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: () => context.pop(),
          ),
          title: const Text(
            'HALIDE PREMIUM',
            style: TextStyle(
              color: Colors.white,
              letterSpacing: 2.5,
              fontWeight: FontWeight.w400,
              fontSize: 14,
            ),
          ),
          centerTitle: true,
        ),
        child: BlocConsumer<BillingBloc, BillingState>(
          listener: (context, state) {
            if (state is PurchaseSuccess) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Welcome to Halide Premium!')),
              );
              context.pop();
            } else if (state is BillingError) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Error: ${state.message}')),
              );
            }
          },
          builder: (context, state) {
            return Column(
              children: [
                const SizedBox(height: 12),
                _buildTierToggle(),
                const SizedBox(height: 32),
                Expanded(
                  child: _buildCarousel(state, currentPlans),
                ),
                const SizedBox(height: 20),
                _buildPageIndicator(currentPlans.length),
                const SizedBox(height: 24),
                _buildFooterLinks(context),
                const SizedBox(height: 40),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildTierToggle() {
    return Container(
      width: 200,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          _buildToggleItem('PLUS', !_isProMode),
          _buildToggleItem('PRO', _isProMode),
        ],
      ),
    );
  }

  Widget _buildToggleItem(String label, bool isSelected) {
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() {
          _isProMode = (label == 'PRO');
        }),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 240),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFFF97316) : Colors.transparent,
            borderRadius: BorderRadius.circular(28),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.white38,
                fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
                fontSize: 11,
                letterSpacing: 1.0,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCarousel(BillingState state, List<PlanDetails> plans) {
    return PageView.builder(
      controller: _pageController,
      onPageChanged: (idx) => setState(() => _currentPage = idx),
      itemCount: plans.length,
      itemBuilder: (context, index) {
        final plan = plans[index];
        final isSelected = _currentPage == index;
        return AnimatedScale(
          scale: isSelected ? 1.0 : 0.9,
          duration: const Duration(milliseconds: 240),
          child: _PlanCard(
            plan: plan,
            isSelected: isSelected,
            isPro: _isProMode,
            onPurchase: (p) => context.read<BillingBloc>().add(PurchasePackage(p)),
            offerings: (state is OfferingsLoaded) ? state.offerings : null,
            isLoading: state is BillingLoading,
          ),
        );
      },
    );
  }

  Widget _buildPageIndicator(int count) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (index) {
        final isActive = _currentPage == index;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 240),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: isActive ? 12 : 6,
          height: 6,
          decoration: BoxDecoration(
            color: isActive ? const Color(0xFFF97316) : Colors.white24,
            borderRadius: BorderRadius.circular(3),
          ),
        );
      }),
    );
  }

  Widget _buildFooterLinks(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _footerLink('Restore Purchases', () => context.read<BillingBloc>().add(RestorePurchases())),
        _footerDivider(),
        _footerLink('Terms of Service', () {}),
        _footerDivider(),
        _footerLink('Privacy Policy', () {}),
      ],
    );
  }

  Widget _footerLink(String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Text(label, style: const TextStyle(color: Colors.white38, fontSize: 10)),
    );
  }

  Widget _footerDivider() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Text('|', style: TextStyle(color: Colors.white.withOpacity(0.1), fontSize: 10)),
    );
  }
}

class _PlanCard extends StatelessWidget {
  final PlanDetails plan;
  final bool isSelected;
  final bool isPro;
  final void Function(rc.Package) onPurchase;
  final rc.Offerings? offerings;
  final bool isLoading;

  const _PlanCard({
    required this.plan,
    required this.isSelected,
    required this.isPro,
    required this.onPurchase,
    this.offerings,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    const orange500 = Color(0xFFF97316);

    // Find RC Package from specific offering (plus or pro)
    rc.Package? package;
    if (offerings != null) {
      final offeringId = isPro ? 'pro' : 'plus';
      final specificOffering = offerings!.all[offeringId];
      if (specificOffering != null) {
        if (plan.id.contains('weekly')) package = specificOffering.weekly;
        if (plan.id.contains('monthly')) package = specificOffering.monthly;
        if (plan.id.contains('annually')) package = specificOffering.annual;
      } else if (offerings!.current != null) {
        // Fallback to current offering if specific ones are not set up yet
        final current = offerings!.current!;
        if (plan.id.contains('weekly')) package = current.weekly;
        if (plan.id.contains('monthly')) package = current.monthly;
        if (plan.id.contains('annually')) package = current.annual;
      }
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 240),
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(
          color: isSelected ? orange500.withOpacity(0.5) : Colors.white.withOpacity(0.1),
          width: isSelected ? 2 : 1,
        ),
        boxShadow: isSelected 
          ? [BoxShadow(color: orange500.withOpacity(0.1), blurRadius: 30, spreadRadius: 2)]
          : [],
      ),
      child: Column(
        children: [
          Icon(plan.icon, color: isSelected ? orange500 : Colors.white30, size: 32),
          const SizedBox(height: 16),
          Text(
            plan.title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.0,
            ),
          ),
          if (plan.isBestValue) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: orange500, borderRadius: BorderRadius.circular(6)),
              child: const Text('BEST VALUE', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w900)),
            ),
          ],
          const SizedBox(height: 24),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: plan.features.map((f) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      Icon(Icons.check_circle, color: orange500, size: 16),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          f.title,
                          style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 13, fontWeight: FontWeight.w300),
                        ),
                      ),
                    ],
                  ),
                )).toList(),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            '${plan.price}${plan.duration}',
            style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900),
          ),
          if (plan.footerText != null) 
             Text(plan.footerText!, style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 10)),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: (package == null || isLoading) ? null : () => onPurchase(package!),
              style: ElevatedButton.styleFrom(
                backgroundColor: orange500,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                elevation: 0,
              ),
              child: isLoading 
                ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 3, color: Colors.white))
                : Text(
                    plan.buttonText.toUpperCase(),
                    style: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.2, fontSize: 14),
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
