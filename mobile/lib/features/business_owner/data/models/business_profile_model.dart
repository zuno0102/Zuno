import 'package:json_annotation/json_annotation.dart';
import 'package:zuno/features/business_owner/domain/entities/business_profile.dart';
import 'package:zuno/shared/data/business_trust_model.dart';
import 'package:zuno/shared/domain/business_trust.dart';

part 'business_profile_model.g.dart';

@JsonSerializable(createToJson: false)
class BusinessProfileModel {
  const BusinessProfileModel({
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
    this.trust,
    this.level = 1,
    this.levelName = 'New',
  });

  factory BusinessProfileModel.fromJson(Map<String, dynamic> json) =>
      _$BusinessProfileModelFromJson(json);

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
  final int level;
  final String levelName;
  final BusinessTrustModel? trust;

  BusinessProfile toEntity() => BusinessProfile(
    id: id,
    businessName: businessName,
    businessType: businessType,
    gstNumber: gstNumber,
    description: description,
    logoUrl: logoUrl,
    verificationStatus: verificationStatus,
    addressLine1: addressLine1,
    addressLine2: addressLine2,
    city: city,
    state: state,
    postalCode: postalCode,
    country: country,
    latitude: latitude,
    longitude: longitude,
    level: level,
    levelName: levelName,
    trust: trust?.toEntity() ?? const BusinessTrust(),
  );
}
