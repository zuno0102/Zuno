// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'business_summary_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

BusinessSummaryModel _$BusinessSummaryModelFromJson(
  Map<String, dynamic> json,
) => BusinessSummaryModel(
  id: json['id'] as String,
  businessName: json['businessName'] as String,
  serviceCategoryNames: (json['serviceCategoryNames'] as List<dynamic>)
      .map((e) => e as String)
      .toList(),
  description: json['description'] as String?,
  logoUrl: json['logoUrl'] as String?,
  city: json['city'] as String?,
  state: json['state'] as String?,
  level: (json['level'] as num?)?.toInt() ?? 1,
  levelName: json['levelName'] as String? ?? 'New',
  ratingAverage: (json['ratingAverage'] as num?)?.toDouble(),
  reviewCount: (json['reviewCount'] as num?)?.toInt() ?? 0,
  completedJobCount: (json['completedJobCount'] as num?)?.toInt() ?? 0,
  startingPrice: (json['startingPrice'] as num?)?.toDouble(),
);
