import 'package:zuno/shared/domain/business_trust.dart';

class BusinessProfile {
  const BusinessProfile({
    required this.id,
    required this.businessName,
    required this.verificationStatus,
    this.businessType,
    this.gstNumber,
    this.description,
    this.logoUrl,
    this.addressLine1,
    this.addressLine2,
    this.city,
    this.state,
    this.postalCode,
    this.country,
    this.latitude,
    this.longitude,
    this.trust = const BusinessTrust(),
    this.level = 1,
    this.levelName = 'New',
  });

  final String id;
  final String businessName;
  final String? businessType;
  final String? gstNumber;
  final String? description;
  final String? logoUrl;
  final String verificationStatus;
  final String? addressLine1;
  final String? addressLine2;
  final String? city;
  final String? state;
  final String? postalCode;
  final String? country;
  final double? latitude;
  final double? longitude;

  /// 1-5, earned from jobs seen through and paid for.
  final int level;
  final String levelName;

  /// What customers see, and what workers see — two records, not one score.
  final BusinessTrust trust;

  bool get hasAddress => addressLine1 != null && addressLine1!.isNotEmpty;
}
