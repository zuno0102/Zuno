import 'package:json_annotation/json_annotation.dart';
import 'package:zuno/features/customer/domain/entities/business_summary.dart';

part 'business_summary_model.g.dart';

@JsonSerializable(createToJson: false)
class BusinessSummaryModel {
  const BusinessSummaryModel({
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

  factory BusinessSummaryModel.fromJson(Map<String, dynamic> json) =>
      _$BusinessSummaryModelFromJson(json);

  final String id;
  final String businessName;
  final String? description;
  final String? logoUrl;
  final String? city;
  final String? state;
  final List<String> serviceCategoryNames;
  final int level;

  /// Named by the server, so every screen agrees on what a level is called.
  final String levelName;
  final double? ratingAverage;
  final int reviewCount;
  final int completedJobCount;
  final double? startingPrice;

  BusinessSummary toEntity() => BusinessSummary(
    id: id,
    businessName: businessName,
    description: description,
    logoUrl: logoUrl,
    city: city,
    state: state,
    serviceCategoryNames: serviceCategoryNames,
    level: level,
    levelName: levelName,
    ratingAverage: ratingAverage,
    reviewCount: reviewCount,
    completedJobCount: completedJobCount,
    startingPrice: startingPrice,
  );
}
