import 'package:zuno/core/utils/formatting.dart';

/// One service as a customer browses it, with just enough of the business attached to judge.
class ServiceListing {
  const ServiceListing({
    required this.id,
    required this.name,
    required this.serviceCategoryName,
    required this.serviceCategoryId,
    required this.price,
    required this.priceType,
    required this.businessOwnerProfileId,
    required this.businessName,
    this.description,
    this.imageUrl,
    this.businessLogoUrl,
    this.city,
    this.level = 1,
    this.levelName = 'New',
    this.ratingAverage,
    this.reviewCount = 0,
  });

  final String id;
  final String name;
  final String? description;
  final String serviceCategoryName;
  final String serviceCategoryId;
  final double price;
  final String priceType;

  /// First image the business uploaded. Null when they have added none.
  final String? imageUrl;

  final String businessOwnerProfileId;
  final String businessName;
  final String? businessLogoUrl;
  final String? city;
  final int level;

  /// Named by the server, so every screen agrees on what a level is called.
  final String levelName;
  final double? ratingAverage;
  final int reviewCount;

  /// Enough ratings to be worth showing rather than misleading.
  bool get hasRating => ratingAverage != null && reviewCount > 0;

  bool get hasEarnedLevel => level > 1;

  /// "From ₹15,000" — a starting figure, since most services price per variant.
  ///
  /// The unit is part of the figure, not decoration: "From ₹500" on a per-person caterer reads as
  /// the price of the job when it is the price of one head. This used to format the number by
  /// hand and so said nothing about the unit at all.
  String get priceLabel =>
      'From ${rupees(price)}${priceUnitSuffix(priceType)}';
}
