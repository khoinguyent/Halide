import 'package:purchases_flutter/purchases_flutter.dart';

/// Human-readable line for the paywall footer, from App Store / Play product metadata.
/// Returns null if the product has no introductory offer (configure trial in store consoles).
String? introOfferShortLabel(StoreProduct product) {
  final intro = product.introductoryPrice;
  if (intro == null) return null;

  final isFreeTrial = intro.price <= 0.001;
  if (!isFreeTrial) {
    return '${intro.priceString} intro · then regular price';
  }

  final n = intro.periodNumberOfUnits;
  if (n <= 0) return 'Free trial';

  final unit = switch (intro.periodUnit) {
    PeriodUnit.day => n == 1 ? 'day' : 'days',
    PeriodUnit.week => n == 1 ? 'week' : 'weeks',
    PeriodUnit.month => n == 1 ? 'month' : 'months',
    PeriodUnit.year => n == 1 ? 'year' : 'years',
    PeriodUnit.unknown => 'period',
  };
  return '$n-$unit free trial';
}

/// Same offering as [proPackageForSelection], for reading both package prices.
Offering? proOfferingFrom(Offerings offerings) {
  try {
    return offerings.all.values.firstWhere(
      (o) => o.identifier.toLowerCase().contains('pro'),
      orElse: () => offerings.current!,
    );
  } catch (_) {
    return null;
  }
}

/// Pro package for current billing period toggle, or null.
Package? proPackageForSelection(Offerings offerings, {required bool annual}) {
  try {
    final offering = proOfferingFrom(offerings);
    if (offering == null) return null;
    return annual ? offering.annual : offering.monthly;
  } catch (_) {
    return null;
  }
}
