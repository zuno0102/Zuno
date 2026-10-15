// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'service_listing_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ServiceListingModel _$ServiceListingModelFromJson(Map<String, dynamic> json) =>
    ServiceListingModel(
      id: json['id'] as String,
      name: json['name'] as String,
      serviceCategoryName: json['serviceCategoryName'] as String,
      serviceCategoryId: json['serviceCategoryId'] as String,
      price: (json['price'] as num).toDouble(),
      priceType: json['priceType'] as String,
      businessOwnerProfileId: json['businessOwnerProfileId'] as String,
      businessName: json['businessName'] as String,
      description: json['description'] as String?,
      imageUrl: json['imageUrl'] as String?,
      businessLogoUrl: json['businessLogoUrl'] as String?,
      city: json['city'] as String?,
      level: (json['level'] as num?)?.toInt() ?? 1,
      levelName: json['levelName'] as String? ?? 'New',
      ratingAverage: (json['ratingAverage'] as num?)?.toDouble(),
      reviewCount: (json['reviewCount'] as num?)?.toInt() ?? 0,
    );
