/// In-app purchase identifiers for System Cloud storage add-ons (stackable **consumables** in the stores).
/// These strings must match **exactly** in App Store Connect, Google Play Console, and RevenueCat.
class StorageAddonCatalog {
  StorageAddonCatalog._();

  /// Ordered smallest → largest. [guidePriceUsd] is fallback copy when store prices are not loaded.
  static const List<StorageAddonTier> tiers = [
    StorageAddonTier(
      productId: 'halide_storage_5gb',
      gigabytes: 5,
      shortLabel: '5 GB',
      blurb: 'Light archive — rolls, thumbnails, and metadata.',
      guidePriceUsd: r'$3.99',
    ),
    StorageAddonTier(
      productId: 'halide_storage_10gb',
      gigabytes: 10,
      shortLabel: '10 GB',
      blurb: 'Comfortable headroom for active shooters.',
      guidePriceUsd: r'$6.99',
    ),
    StorageAddonTier(
      productId: 'halide_storage_50gb',
      gigabytes: 50,
      shortLabel: '50 GB',
      blurb: 'Maximum headroom for large libraries and full-res archives.',
      guidePriceUsd: r'$24.99',
    ),
  ];

  static List<String> get allProductIds =>
      tiers.map((t) => t.productId).toList(growable: false);
}

class StorageAddonTier {
  final String productId;
  final int gigabytes;
  final String shortLabel;
  final String blurb;
  final String guidePriceUsd;

  const StorageAddonTier({
    required this.productId,
    required this.gigabytes,
    required this.shortLabel,
    required this.blurb,
    required this.guidePriceUsd,
  });
}
