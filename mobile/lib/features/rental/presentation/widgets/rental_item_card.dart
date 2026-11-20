import 'package:flutter/material.dart';
import 'package:zuno/core/utils/formatting.dart';
import 'package:zuno/features/rental/data/rental_api.dart';
import 'package:zuno/features/rental/domain/entities/rental_customer.dart';
import 'package:zuno/shared/widgets/listing_card.dart';
import 'package:zuno/shared/widgets/rating_line.dart';

/// A rent item on the customer's Rent home and search — the shared [ListingCard] with the rate on
/// the photo and the stars under the name.
class RentalItemCard extends StatelessWidget {
  const RentalItemCard({required this.card, required this.onTap, super.key});

  final RentalCard card;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ListingCard(
    key: ValueKey('rental-card-${card.id}'),
    imageUrl: rentalPhotoUrl(card.imageUrl),
    price: '${rupees(card.price)}${card.unitSuffix}',
    title: card.name,
    rating: RatingLine.of(
      card.rating,
      key: ValueKey('rental-card-rating-${card.id}'),
    ),
    placeLine: [card.categoryName, ?card.districtName].join(' · '),
    businessName: card.businessName,
    onTap: onTap,
  );
}

/// A path the Rent server returned, as a full address; null stays null.
String? rentalPhotoUrl(String? path) =>
    path == null || path.isEmpty ? null : RentApi.mediaUrl(path);
