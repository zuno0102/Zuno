// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'business_detail_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

BusinessDetailModel _$BusinessDetailModelFromJson(Map<String, dynamic> json) =>
    BusinessDetailModel(
      id: json['id'] as String,
      businessName: json['businessName'] as String,
      services: (json['services'] as List<dynamic>)
          .map((e) => CustomerServiceModel.fromJson(e as Map<String, dynamic>))
          .toList(),
      description: json['description'] as String?,
      logoUrl: json['logoUrl'] as String?,
      addressLine1: json['addressLine1'] as String?,
      city: json['city'] as String?,
      state: json['state'] as String?,
      country: json['country'] as String?,
      ratingAverage: (json['ratingAverage'] as num?)?.toDouble(),
      reviewCount: (json['reviewCount'] as num?)?.toInt() ?? 0,
      serviceRatingAverage: (json['serviceRatingAverage'] as num?)?.toDouble(),
      serviceRatingCount: (json['serviceRatingCount'] as num?)?.toInt() ?? 0,
      rentRatingAverage: (json['rentRatingAverage'] as num?)?.toDouble(),
      rentRatingCount: (json['rentRatingCount'] as num?)?.toInt() ?? 0,
    );
