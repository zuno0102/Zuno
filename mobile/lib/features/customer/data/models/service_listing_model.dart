import 'package:json_annotation/json_annotation.dart';
import 'package:zuno/features/customer/domain/entities/service_listing.dart';

part 'service_listing_model.g.dart';

@JsonSerializable(createToJson: false)
class ServiceListingModel {
  const ServiceListingModel({
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

  factory ServiceListingModel.fromJson(Map<String, dynamic> json) =>
      _$ServiceListingModelFromJson(json);

  final String id;
  final String name;
  final String? description;
  final String serviceCategoryName;
  final String serviceCategoryId;
  final double price;
  final String priceType;
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

  ServiceListing toEntity() => ServiceListing(
    id: id,
    name: name,
    description: description,
    serviceCategoryName: serviceCategoryName,
    serviceCategoryId: serviceCategoryId,
    price: price,
    priceType: priceType,
    imageUrl: imageUrl,
    businessOwnerProfileId: businessOwnerProfileId,
    businessName: businessName,
    businessLogoUrl: businessLogoUrl,
    city: city,
    level: level,
    levelName: levelName,
    ratingAverage: ratingAverage,
    reviewCount: reviewCount,
  );
}
