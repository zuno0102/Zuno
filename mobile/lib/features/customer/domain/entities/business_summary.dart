class BusinessSummary {
  const BusinessSummary({
    required this.id,
    required this.businessName,
    required this.serviceCategoryNames,
    this.description,
    this.logoUrl,
    this.city,
    this.state,
    this.level = 1,
    this.levelName = 'New',
    this.ratingAverage,
    this.reviewCount = 0,
    this.completedJobCount = 0,
    this.startingPrice,
  });

  final String id;
  final String businessName;
  final String? description;
  final String? logoUrl;
  final String? city;
  final String? state;
  final List<String> serviceCategoryNames;

  /// 1–5, earned from jobs finished and paid for. Shown as a badge.
  final int level;

  /// Named by the server, so every screen agrees on what a level is called.
  final String levelName;

  /// Null until anyone has rated them — which is different from a rating of zero.
  final double? ratingAverage;
  final int reviewCount;
  final int completedJobCount;

  /// The cheapest thing they offer. Null when nothing is priced.
  final double? startingPrice;

  String? get location {
    final parts = [city, state].whereType<String>().where((s) => s.isNotEmpty);
    return parts.isEmpty ? null : parts.join(', ');
  }

  /// Whether there are enough ratings to be worth showing rather than misleading.
  bool get hasRating => ratingAverage != null && reviewCount > 0;

  /// Only worth a badge once it means something — every business starts at 1.
  bool get hasEarnedLevel => level > 1;
}
