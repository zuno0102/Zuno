import 'package:zuno/features/rental/domain/entities/rental_item.dart';
import 'package:zuno/features/rental/domain/entities/rental_payment.dart';
import 'package:zuno/shared/domain/star_rating.dart';

/// Which side of a rent order is looking: the business that rents the item out, or the customer who
/// rented it. The same order screens serve both; this picks the server routes and what may be done.
enum RentalAudience { business, customer }

/// A rent item on a customer card — photo, name, rate, where, and who rents it out.
class RentalCard {
  const RentalCard({
    required this.id,
    required this.name,
    required this.categoryName,
    required this.priceType,
    required this.price,
    required this.unitSuffix,
    required this.businessName,
    this.imageUrl,
    this.districtName,
    this.rating = const StarRating(),
  });

  final String id;
  final String name;
  final String categoryName;
  final String priceType;
  final double price;

  /// "/day", from the server's rate-type table.
  final String unitSuffix;
  final String businessName;
  final String? imageUrl;
  final String? districtName;

  /// How customers rated this item.
  final StarRating rating;
}

/// How a Rent home section lays out its items, as the server's section table says.
enum RentalHomeLayout {
  /// A row that scrolls sideways.
  strip,

  /// Two columns.
  grid;

  static RentalHomeLayout from(String value) =>
      value.toLowerCase() == 'strip' ? strip : grid;
}

/// One section of the customer's Rent home — "Popular near you" as a strip, "Explore" as a grid.
class RentalHomeSection {
  const RentalHomeSection({
    required this.code,
    required this.title,
    required this.layout,
    required this.items,
  });

  final String code;
  final String title;
  final RentalHomeLayout layout;
  final List<RentalCard> items;
}

/// A rent item as a customer opens it.
class RentalItemDetail {
  const RentalItemDetail({
    required this.card,
    required this.priceTypeName,
    required this.quantityOwned,
    this.description,
    this.subCategoryName,
    this.media = const [],
    this.districts = const [],
    this.questions = const [],
    this.businessLogoUrl,
    this.advanceType = 'None',
    this.advanceAmount,
    this.cancelSteps = const [],
    this.cancelUnit = RentalCancelUnit.day,
    this.cancelChargeType = RentalCancelChargeType.byTimeLeft,
    this.cancelPercentPerDay,
    this.maxCancelPercent = 0,
  });

  final RentalCard card;
  final String? description;
  final String? subCategoryName;

  /// "Per day", from the rate-type table.
  final String priceTypeName;
  final int quantityOwned;
  final List<RentalItemMedia> media;
  final List<RentalItemDistrict> districts;
  final List<RentalItemQuestion> questions;

  /// A path on the Service server, where business profiles live.
  final String? businessLogoUrl;

  /// `None`, `PerOrder` or `PerPiece`.
  final String advanceType;
  final double? advanceAmount;

  /// What cancelling costs by time left; empty is free cancellation.
  final List<RentalCancelStep> cancelSteps;

  /// [RentalCancelUnit.day] or [RentalCancelUnit.hour].
  final String cancelUnit;

  /// [RentalCancelChargeType.byTimeLeft] (the steps) or [RentalCancelChargeType.perRentalDay].
  final String cancelChargeType;

  /// For a per-rental-day charge: the percent for each day (or hour) rented.
  final double? cancelPercentPerDay;

  /// The most the charge can add up to for this kind of item.
  final double maxCancelPercent;

  List<String> get imageUrls => [
    for (final m in [
      ...media,
    ]..sort((a, b) => a.sortOrder.compareTo(b.sortOrder)))
      if (!m.isVideo) m.url,
  ];

  RentalItemMedia? get video => media.where((m) => m.isVideo).firstOrNull;
}

/// What a customer fills in to book.
class RentalBookingInput {
  const RentalBookingInput({
    required this.rentalItemId,
    required this.quantity,
    required this.startDate,
    required this.endDate,
    required this.deliveryAddress,
    required this.districtId,
    required this.customerPhone,
    this.answers = const {},
  });

  final String rentalItemId;
  final int quantity;
  final DateTime startDate;
  final DateTime endDate;
  final String deliveryAddress;
  final String districtId;

  /// The 10 digits of the mobile the customer verified with a code.
  final String customerPhone;

  /// Question id → the customer's answer.
  final Map<String, String> answers;
}

/// A code was sent to the customer's mobile — or not needed, the number being verified already.
class RentalPhoneCodeSent {
  const RentalPhoneCodeSent({
    required this.phone,
    this.alreadyVerified = false,
    this.expiresInSeconds = 0,
    this.resendInSeconds = 0,
    this.testCode,
  });

  final String phone;
  final bool alreadyVerified;
  final int expiresInSeconds;
  final int resendInSeconds;

  /// The code itself, only while no SMS is really sent — shown so it can be typed in.
  final String? testCode;
}
