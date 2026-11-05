import 'package:zuno/shared/domain/business_trust.dart';
import 'package:zuno/shared/domain/star_rating.dart';

class BusinessProfile {
  const BusinessProfile({
    required this.id,
    required this.businessName,
    required this.verificationStatus,
    this.businessType,
    this.gstNumber,
    this.description,
    this.logoUrl,
    this.upiId,
    this.missingDetails = const [],
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
    this.successfulJobs = 0,
    this.lineRatings = const LineRatings(),
  });

  final String id;
  final String businessName;
  final String? businessType;
  final String? gstNumber;
  final String? description;
  final String? logoUrl;

  /// Where customers pay by UPI. Every payment QR the business shows — Service and Rent — is made
  /// from it. Null until the business finishes its profile.
  final String? upiId;

  /// What the business still has to fill in, in the server's words (e.g. "UPI ID").
  final List<String> missingDetails;

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

  /// Jobs seen through on every line — Service jobs plus Rent orders — which the level counts.
  final int successfulJobs;

  /// Its stars on Service and on Rent, apart.
  final LineRatings lineRatings;

  /// What customers see, and what workers see — two records, not one score.
  final BusinessTrust trust;

  /// "12 successful jobs" / "1 successful job".
  String get successfulJobsLabel =>
      '$successfulJobs successful ${successfulJobs == 1 ? 'job' : 'jobs'}';

  bool get hasAddress => addressLine1 != null && addressLine1!.isNotEmpty;

  /// Whether every required detail is filled in.
  bool get isComplete => missingDetails.isEmpty;
}
