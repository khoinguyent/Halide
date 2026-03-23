import 'package:flutter/material.dart';

class PlanFeature {
  final String title;
  final bool isIncluded;
  const PlanFeature(this.title, {this.isIncluded = true});
}

class PlanDetails {
  final String id;
  final String title;
  final String subtitle;
  final String price;
  final String duration;
  final List<PlanFeature> features;
  final IconData icon;
  final bool isBestValue;
  final String? footerText;
  final String buttonText;

  const PlanDetails({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.price,
    required this.duration,
    required this.features,
    required this.icon,
    this.isBestValue = false,
    this.footerText,
    this.buttonText = 'Start Trial',
  });
}

final List<PlanDetails> plusPlans = [
  const PlanDetails(
    id: 'plus_weekly',
    title: 'PLUS WEEKLY',
    subtitle: 'Essential manual control',
    price: '\$1.99',
    duration: '/ WEEK',
    icon: Icons.camera_alt_outlined,
    features: [
      PlanFeature('Basic Manual Controls'),
      PlanFeature('HEIC Support'),
      PlanFeature('Standard Histogram'),
      PlanFeature('Focus Peaking'),
    ],
  ),
  const PlanDetails(
    id: 'plus_monthly',
    title: 'PLUS MONTHLY',
    subtitle: 'Better for hobbyists',
    price: '\$5.99',
    duration: '/ MONTH',
    icon: Icons.lens_outlined,
    features: [
      PlanFeature('Basic Manual Controls'),
      PlanFeature('HEIC Support'),
      PlanFeature('Standard Histogram'),
      PlanFeature('Focus Peaking'),
    ],
  ),
  const PlanDetails(
    id: 'plus_annually',
    title: 'PLUS ANNUALLY',
    subtitle: 'Best Value Plus',
    price: '\$39.99',
    duration: '/ YEAR',
    isBestValue: true,
    icon: Icons.star_border_rounded,
    features: [
      PlanFeature('Basic Manual Controls'),
      PlanFeature('HEIC Support'),
      PlanFeature('Standard Histogram'),
      PlanFeature('Focus Peaking'),
    ],
  ),
];

final List<PlanDetails> proPlans = [
  const PlanDetails(
    id: 'pro_weekly',
    title: 'PRO WEEKLY',
    subtitle: 'Unlock everything RAW',
    price: '\$3.99',
    duration: '/ WEEK',
    icon: Icons.auto_awesome_outlined,
    features: [
      PlanFeature('RAW & ProRAW Support'),
      PlanFeature('Advanced Manual Controls'),
      PlanFeature('RGB Histogram & Waveforms'),
      PlanFeature('Focus Peaking & Zebra'),
      PlanFeature('Custom Lenses & Presets'),
      PlanFeature('Exclusive Tutorial Access'),
    ],
  ),
  const PlanDetails(
    id: 'pro_monthly',
    title: 'PRO MONTHLY',
    subtitle: 'The professional standard',
    price: '\$9.99',
    duration: '/ MONTH',
    icon: Icons.diamond_outlined,
    features: [
      PlanFeature('RAW & ProRAW Support'),
      PlanFeature('Advanced Manual Controls'),
      PlanFeature('RGB Histogram & Waveforms'),
      PlanFeature('Focus Peaking & Zebra'),
      PlanFeature('Custom Lenses & Presets'),
      PlanFeature('Exclusive Tutorial Access'),
    ],
  ),
  const PlanDetails(
    id: 'pro_annually',
    title: 'PRO ANNUALLY',
    subtitle: 'Best Value Pro',
    price: '\$59.99',
    duration: '/ YEAR',
    isBestValue: true,
    icon: Icons.workspace_premium_outlined,
    features: [
      PlanFeature('RAW & ProRAW Support'),
      PlanFeature('Advanced Manual Controls'),
      PlanFeature('RGB Histogram & Waveforms'),
      PlanFeature('Focus Peaking & Zebra'),
      PlanFeature('Custom Lenses & Presets'),
      PlanFeature('Exclusive Tutorial Access'),
    ],
  ),
];
