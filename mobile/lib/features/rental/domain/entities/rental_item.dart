/// How a rent item is charged — the server's enum names, matched as written.
class RentalPriceType {
  const RentalPriceType._();

  static const hourly = 'Hourly';
  static const daily = 'Daily';

  /// Shown as "Per item": one price for each item, whatever the rental's length.
  static const fixed = 'Fixed';
}

/// One way of charging the form offers, read from the Rent server's rate-type table — so the
/// names, the line under each, the "/day" suffix and their order change without a release.
class RentalPriceTypeOption {
  const RentalPriceTypeOption({
    required this.code,
    required this.name,
    required this.detail,
    required this.unitSuffix,
  });

  /// What an item save sends: [RentalPriceType.daily] and the rest.
  final String code;
  final String name;
  final String detail;
  final String unitSuffix;
}

/// Something the business asks every customer renting the item.
class RentalItemQuestion {
  const RentalItemQuestion({
    required this.id,
    required this.prompt,
    required this.isRequired,
  });

  final String id;
  final String prompt;
  final bool isRequired;
}

class RentalItemMedia {
  const RentalItemMedia({
    required this.id,
    required this.mediaType,
    required this.url,
    required this.sortOrder,
  });

  final String id;

  /// `Image` or `Video`.
  final String mediaType;
  final String url;
  final int sortOrder;

  bool get isVideo => mediaType == 'Video';
}

class RentalItemDistrict {
  const RentalItemDistrict({
    required this.id,
    required this.name,
    required this.stateId,
    required this.stateName,
  });

  final String id;
  final String name;
  final String stateId;
  final String stateName;
}

/// Something the business rents out, and how many of it they have.
class RentalItem {
  const RentalItem({
    required this.id,
    required this.rentalCategoryId,
    required this.rentalCategoryName,
    required this.name,
    required this.priceType,
    required this.price,
    required this.quantityOwned,
    required this.isAvailable,
    this.rentalSubCategoryId,
    this.rentalSubCategoryName,
    this.description,
    this.media = const [],
    this.districts = const [],
    this.questions = const [],
    this.advanceType = 'None',
    this.advanceAmount,
  });

  final String id;
  final String rentalCategoryId;
  final String rentalCategoryName;
  final String? rentalSubCategoryId;
  final String? rentalSubCategoryName;
  final String name;
  final String? description;
  final String priceType;
  final double price;
  final int quantityOwned;
  final bool isAvailable;
  final List<RentalItemMedia> media;
  final List<RentalItemDistrict> districts;

  /// In display order.
  final List<RentalItemQuestion> questions;

  /// `None`, `PerOrder` or `PerPiece` — an advance once set is asked on every order.
  final String advanceType;

  /// For the whole order or for each piece; null when no advance is asked.
  final double? advanceAmount;

  bool get asksAdvance => advanceType != 'None' && (advanceAmount ?? 0) > 0;

  /// "Tools & machines › Cutting machine", or just the category.
  String get categoryLine => rentalSubCategoryName == null
      ? rentalCategoryName
      : '$rentalCategoryName › $rentalSubCategoryName';

  String? imageUrlForSlot(int slot) => media
      .where((m) => !m.isVideo && m.sortOrder == slot)
      .map((m) => m.url)
      .firstOrNull;

  RentalItemMedia? get video => media.where((m) => m.isVideo).firstOrNull;
}

/// The business home screen's Rent tiles.
class RentalSummary {
  const RentalSummary({
    required this.totalItems,
    required this.availableItems,
    required this.unavailableItems,
    required this.unitsAvailable,
  });

  final int totalItems;
  final int availableItems;
  final int unavailableItems;

  /// Pieces across the items available now: 200 chairs and 1 machine make 201.
  final int unitsAvailable;
}

class RentalSubCategory {
  const RentalSubCategory({required this.id, required this.name});

  final String id;
  final String name;
}

class RentalCategory {
  const RentalCategory({
    required this.id,
    required this.name,
    this.iconName,
    this.subCategories = const [],
  });

  final String id;
  final String name;
  final String? iconName;
  final List<RentalSubCategory> subCategories;
}

/// What the business fills in for a rent item — the same for adding and editing.
class RentalItemInput {
  const RentalItemInput({
    required this.rentalCategoryId,
    required this.name,
    required this.priceType,
    required this.price,
    required this.quantityOwned,
    required this.isAvailable,
    required this.districtIds,
    this.rentalSubCategoryId,
    this.description,
    this.questions = const [],
    this.advanceType = 'None',
    this.advanceAmount,
  });

  final String rentalCategoryId;
  final String? rentalSubCategoryId;
  final String name;
  final String? description;
  final String priceType;
  final double price;
  final int quantityOwned;
  final bool isAvailable;
  final List<String> districtIds;

  /// The whole question set, in order, as the server takes it: an id only on a saved question.
  final List<Map<String, dynamic>> questions;

  /// `None`, `PerOrder` or `PerPiece`.
  final String advanceType;

  /// Ignored by the server when no advance is asked.
  final double? advanceAmount;

  Map<String, dynamic> toJson() => {
    'rentalCategoryId': rentalCategoryId,
    'rentalSubCategoryId': rentalSubCategoryId,
    'name': name,
    'description': description,
    'priceType': priceType,
    'price': price,
    'quantityOwned': quantityOwned,
    'isAvailable': isAvailable,
    'districtIds': districtIds,
    'questions': questions,
    'advanceType': advanceType,
    'advanceAmount': advanceAmount,
  };
}
