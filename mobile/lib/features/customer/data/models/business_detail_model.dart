import 'package:json_annotation/json_annotation.dart';
import 'package:zuno/features/customer/data/models/customer_service_model.dart';
import 'package:zuno/features/customer/domain/entities/business_detail.dart';
import 'package:zuno/shared/domain/star_rating.dart';

part 'business_detail_model.g.dart';

@JsonSerializable(createToJson: false)
class BusinessDetailModel {
  const BusinessDetailModel({
    required this.id,
    required this.businessName,
    required this.services,
    this.description,
    this.logoUrl,
    this.addressLine1,
    this.city,
    this.state,
    this.country,
    this.ratingAverage,
    this.reviewCount = 0,
    this.serviceRatingAverage,
    this.serviceRatingCount = 0,
    this.rentRatingAverage,
    this.rentRatingCount = 0,
  });

  factory BusinessDetailModel.fromJson(Map<String, dynamic> json) =>
      _$BusinessDetailModelFromJson(json);

  final String id;
  final String businessName;
  final String? description;
  final String? logoUrl;
  final String? addressLine1;
  final String? city;
  final String? state;
  final String? country;
  final List<CustomerServiceModel> services;

  /// The overall rating across every line; null until there are enough ratings.
  final double? ratingAverage;
  final int reviewCount;
  final double? serviceRatingAverage;
  final int serviceRatingCount;
  final double? rentRatingAverage;
  final int rentRatingCount;

  BusinessDetail toEntity() => BusinessDetail(
    id: id,
    businessName: businessName,
    description: description,
    logoUrl: logoUrl,
    addressLine1: addressLine1,
    city: city,
    state: state,
    country: country,
    services: services.map((s) => s.toEntity()).toList(),
    rating: StarRating(average: ratingAverage, count: reviewCount),
    lineRatings: LineRatings.fromFields(
      serviceAverage: serviceRatingAverage,
      serviceCount: serviceRatingCount,
      rentAverage: rentRatingAverage,
      rentCount: rentRatingCount,
    ),
  );
}
