import 'package:zuno/features/customer/domain/entities/customer_service.dart';
import 'package:zuno/shared/domain/star_rating.dart';

class BusinessDetail {
  const BusinessDetail({
    required this.id,
    required this.businessName,
    required this.services,
    this.description,
    this.logoUrl,
    this.addressLine1,
    this.city,
    this.state,
    this.country,
    this.rating = const StarRating(),
    this.lineRatings = const LineRatings(),
  });

  final String id;
  final String businessName;
  final String? description;
  final String? logoUrl;
  final String? addressLine1;
  final String? city;
  final String? state;
  final String? country;
  final List<CustomerService> services;

  /// The overall rating across every line it runs.
  final StarRating rating;

  /// Its stars on Service and on Rent, apart.
  final LineRatings lineRatings;
}
