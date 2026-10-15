// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'business_profile_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

BusinessProfileModel _$BusinessProfileModelFromJson(
  Map<String, dynamic> json,
) => BusinessProfileModel(
  id: json['id'] as String,
  businessName: json['businessName'] as String,
  verificationStatus: json['verificationStatus'] as String,
  businessType: json['businessType'] as String?,
  gstNumber: json['gstNumber'] as String?,
  description: json['description'] as String?,
  logoUrl: json['logoUrl'] as String?,
  addressLine1: json['addressLine1'] as String?,
  addressLine2: json['addressLine2'] as String?,
  city: json['city'] as String?,
  state: json['state'] as String?,
  postalCode: json['postalCode'] as String?,
  country: json['country'] as String?,
  latitude: (json['latitude'] as num?)?.toDouble(),
  longitude: (json['longitude'] as num?)?.toDouble(),
  trust: json['trust'] == null
      ? null
      : BusinessTrustModel.fromJson(json['trust'] as Map<String, dynamic>),
  level: (json['level'] as num?)?.toInt() ?? 1,
  levelName: json['levelName'] as String? ?? 'New',
);
