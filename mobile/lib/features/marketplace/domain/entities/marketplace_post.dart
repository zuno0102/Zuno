/// What a post is — decides which parts of the form show and which rules the server checks.
abstract final class MarketplacePostKind {
  static const listing = 'Listing';
  static const foodOffer = 'FoodOffer';
  static const advertisement = 'Advertisement';
}

/// Where a post stands, as shown. "Expired" is an Active post whose end time has passed.
abstract final class MarketplacePostStatus {
  static const active = 'Active';
  static const paused = 'Paused';
  static const closed = 'Closed';
  static const expired = 'Expired';
}

/// Retail sells one at a time; wholesale sells in bulk to other businesses (B2B).
abstract final class MarketplaceTradeType {
  static const retail = 'Retail';
  static const wholesale = 'Wholesale';
}

/// How a category's own detail is filled in.
abstract final class MarketplaceFieldType {
  static const text = 'Text';
  static const number = 'Number';
  static const select = 'Select';
}

/// A kind of thing posted — "Vehicles", "Food offers". Set up by the super admin.
class MarketplaceCategory {
  const MarketplaceCategory({
    required this.id,
    required this.name,
    required this.slug,
    required this.kind,
    required this.allowsWholesale,
    required this.displayOrder,
    required this.isActive,
    required this.fields,
    this.iconName,
  });

  final String id;
  final String name;
  final String slug;
  final String? iconName;
  final String kind;
  final bool allowsWholesale;
  final int displayOrder;
  final bool isActive;
  final List<MarketplaceCategoryField> fields;
}

/// A detail a category asks for, e.g. "KM driven" (a number in km) or "Fuel" (one of a list).
class MarketplaceCategoryField {
  const MarketplaceCategoryField({
    required this.id,
    required this.key,
    required this.label,
    required this.fieldType,
    required this.options,
    required this.isRequired,
    required this.displayOrder,
    required this.isActive,
    this.unit,
  });

  final String id;
  final String key;
  final String label;
  final String fieldType;
  final List<String> options;
  final String? unit;
  final bool isRequired;
  final int displayOrder;
  final bool isActive;
}

/// A move the business may make on a post now, from the server's transitions table.
class MarketplacePostAction {
  const MarketplacePostAction({
    required this.toStatus,
    required this.name,
    required this.needsConfirm,
  });

  final String toStatus;
  final String name;
  final bool needsConfirm;
}

/// One thing a business has put up: a listing, a food offer or an advertisement.
class MarketplacePost {
  const MarketplacePost({
    required this.id,
    required this.categoryId,
    required this.categoryName,
    required this.kind,
    required this.status,
    required this.title,
    required this.tradeType,
    required this.districtId,
    required this.districtName,
    required this.stateId,
    required this.stateName,
    required this.attributes,
    required this.imageUrls,
    required this.actions,
    this.categoryIconName,
    this.description,
    this.price,
    this.priceUnit,
    this.minOrderQuantity,
    this.quantity,
    this.originalPrice,
    this.startsAt,
    this.endsAt,
    this.contactPhone,
    this.area,
    this.latitude,
    this.longitude,
  });

  final String id;
  final String categoryId;
  final String categoryName;
  final String? categoryIconName;
  final String kind;
  final String status;
  final String title;
  final String? description;
  final double? price;
  final String? priceUnit;
  final String tradeType;
  final int? minOrderQuantity;
  final int? quantity;
  final double? originalPrice;
  final DateTime? startsAt;
  final DateTime? endsAt;
  final String? contactPhone;
  final String districtId;
  final String districtName;
  final String stateId;
  final String stateName;
  final String? area;
  final double? latitude;
  final double? longitude;

  /// The category's own details, by field key.
  final Map<String, String> attributes;

  /// Saved photo paths by slot; slot 0 is the cover (an advertisement's banner).
  final Map<int, String> imageUrls;

  final List<MarketplacePostAction> actions;

  String? imageUrlForSlot(int slot) => imageUrls[slot];

  bool get isFoodOffer => kind == MarketplacePostKind.foodOffer;

  bool get isAdvertisement => kind == MarketplacePostKind.advertisement;

  bool get isWholesale => tradeType == MarketplaceTradeType.wholesale;

  /// "Marthandam, Kanyakumari" — the area when given, then the district.
  String get placeLine =>
      [if (area?.isNotEmpty ?? false) area!, districtName].join(', ');
}

/// What the post form sends, for a new post and an edit alike.
class MarketplacePostInput {
  const MarketplacePostInput({
    required this.categoryId,
    required this.title,
    required this.districtId,
    required this.tradeType,
    required this.attributes,
    this.description,
    this.price,
    this.priceUnit,
    this.minOrderQuantity,
    this.quantity,
    this.originalPrice,
    this.startsAt,
    this.endsAt,
    this.contactPhone,
    this.area,
  });

  final String categoryId;
  final String title;
  final String? description;
  final double? price;
  final String? priceUnit;
  final String tradeType;
  final int? minOrderQuantity;
  final int? quantity;
  final double? originalPrice;
  final DateTime? startsAt;
  final DateTime? endsAt;
  final String? contactPhone;
  final String districtId;
  final String? area;
  final Map<String, String> attributes;

  Map<String, dynamic> toJson() => {
    'categoryId': categoryId,
    'title': title,
    'description': description,
    'price': price,
    'priceUnit': priceUnit,
    'tradeType': tradeType,
    'minOrderQuantity': minOrderQuantity,
    'quantity': quantity,
    'originalPrice': originalPrice,
    'startsAt': startsAt?.toUtc().toIso8601String(),
    'endsAt': endsAt?.toUtc().toIso8601String(),
    'contactPhone': contactPhone,
    'districtId': districtId,
    'area': area,
    'attributes': attributes,
  };
}

/// The business's plan, and how much of it is used — the banner over the post list.
class MarketplacePlan {
  const MarketplacePlan({
    required this.code,
    required this.name,
    required this.price,
    required this.maxActivePosts,
    required this.usedActivePosts,
    this.endsAt,
  });

  final String code;
  final String name;
  final double price;
  final int maxActivePosts;
  final int usedActivePosts;
  final DateTime? endsAt;

  bool get canAddActivePost => usedActivePosts < maxActivePosts;
}

/// The counts behind the Marketplace tiles on the business home screen.
class MarketplaceSummary {
  const MarketplaceSummary({
    required this.active,
    required this.paused,
    required this.expired,
    required this.closed,
    required this.plan,
  });

  final int active;
  final int paused;
  final int expired;
  final int closed;
  final MarketplacePlan plan;
}

/// A name from one of the server's reference tables, with its colour where it has one.
class MarketplaceOption {
  const MarketplaceOption({required this.code, required this.name, this.tone});

  final String code;
  final String name;
  final String? tone;
}

/// The post kinds, statuses and limits the Marketplace screens are drawn from.
class MarketplaceOptions {
  const MarketplaceOptions({
    required this.kinds,
    required this.statuses,
    required this.imageSlots,
    required this.maxFoodOfferHours,
    required this.maxAdDays,
  });

  final List<MarketplaceOption> kinds;
  final List<MarketplaceOption> statuses;
  final int imageSlots;
  final int maxFoodOfferHours;
  final int maxAdDays;

  /// The table's name for [code], or [code] itself until the list has loaded.
  String kindName(String code) =>
      kinds.where((k) => k.code == code).firstOrNull?.name ?? code;

  MarketplaceOption? status(String code) =>
      statuses.where((s) => s.code == code).firstOrNull;
}

/// The business's name and whether customers can see its posts — they only see verified ones.
class MarketplaceBusiness {
  const MarketplaceBusiness({
    required this.name,
    required this.isVerified,
    required this.isKnown,
  });

  final String name;
  final bool isVerified;
  final bool isKnown;
}

/// A category as the super admin saves it.
class MarketplaceCategoryInput {
  const MarketplaceCategoryInput({
    required this.name,
    required this.kind,
    required this.allowsWholesale,
    required this.displayOrder,
    required this.isActive,
    this.iconName,
  });

  final String name;
  final String? iconName;
  final String kind;
  final bool allowsWholesale;
  final int displayOrder;
  final bool isActive;

  Map<String, dynamic> toJson() => {
    'name': name,
    'iconName': iconName,
    'kind': kind,
    'allowsWholesale': allowsWholesale,
    'displayOrder': displayOrder,
    'isActive': isActive,
  };
}

/// A category's detail as the super admin saves it.
class MarketplaceFieldInput {
  const MarketplaceFieldInput({
    required this.label,
    required this.fieldType,
    required this.options,
    required this.isRequired,
    required this.displayOrder,
    required this.isActive,
    this.unit,
  });

  final String label;
  final String fieldType;
  final List<String> options;
  final String? unit;
  final bool isRequired;
  final int displayOrder;
  final bool isActive;

  Map<String, dynamic> toJson() => {
    'label': label,
    'fieldType': fieldType,
    'options': options,
    'unit': unit,
    'isRequired': isRequired,
    'displayOrder': displayOrder,
    'isActive': isActive,
  };
}
