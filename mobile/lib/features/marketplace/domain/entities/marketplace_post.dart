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

  /// A used item that went to a buyer. Final, like Closed.
  static const sold = 'Sold';
}

/// New or Used, in a category that keeps stock (Products). A new item has a stock count; a used
/// one is a single piece, marked Sold when it goes. Names for people come from the server's table.
abstract final class MarketplaceItemCondition {
  static const newItem = 'New';
  static const used = 'Used';
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

/// How the posts of a category may sell. Names for people come from the server's table.
abstract final class MarketplaceTradeMode {
  static const retailOnly = 'RetailOnly';
  static const wholesaleOnly = 'WholesaleOnly';
  static const either = 'Either';
}

/// A main kind of thing posted — "Products", "Nearby food" — holding sub-categories. Set up by the
/// super admin.
class MarketplaceCategory {
  const MarketplaceCategory({
    required this.id,
    required this.name,
    required this.shortName,
    required this.slug,
    required this.kind,
    required this.tradeMode,
    required this.displayOrder,
    required this.isActive,
    required this.subCategories,
    required this.fields,
    this.description,
    this.iconName,
    this.tracksStock = false,
  });

  final String id;
  final String name;

  /// Posts here say New or Used: new items keep a stock count, used ones are marked Sold.
  final bool tracksStock;

  /// The few letters the category squares have room for, e.g. "B2B".
  final String shortName;

  /// What goes in it, e.g. "Sarees, shirts, toys" — shown in the post form's picker.
  final String? description;
  final String slug;
  final String? iconName;
  final String kind;
  final String tradeMode;
  final int displayOrder;
  final bool isActive;
  final List<MarketplaceSubCategory> subCategories;
  final List<MarketplaceCategoryField> fields;

  bool get isWholesaleOnly => tradeMode == MarketplaceTradeMode.wholesaleOnly;

  bool get sellsEitherWay => tradeMode == MarketplaceTradeMode.either;

  /// The details a post under [subCategoryId] is asked: the whole category's, then that one's.
  List<MarketplaceCategoryField> fieldsFor(String? subCategoryId) =>
      [
        for (final f in fields)
          if (f.subCategoryId == null || f.subCategoryId == subCategoryId) f,
      ]..sort((a, b) {
        final level = (a.subCategoryId == null ? 0 : 1).compareTo(
          b.subCategoryId == null ? 0 : 1,
        );
        return level != 0 ? level : a.displayOrder.compareTo(b.displayOrder);
      });
}

/// A narrower kind within a main category, e.g. "Sarees" under Products.
class MarketplaceSubCategory {
  const MarketplaceSubCategory({
    required this.id,
    required this.name,
    required this.slug,
    required this.displayOrder,
    required this.isActive,
    this.iconName,
  });

  final String id;
  final String name;
  final String slug;
  final String? iconName;
  final int displayOrder;
  final bool isActive;
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
    this.subCategoryId,
    this.unit,
  });

  final String id;

  /// The one sub-category it is asked for; null for the whole category.
  final String? subCategoryId;
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
    this.subCategoryId,
    this.subCategoryName,
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
    this.condition,
    this.isOutOfStock = false,
    this.canUpdateStock = false,
  });

  final String id;
  final String categoryId;
  final String categoryName;

  /// [MarketplaceItemCondition] in a category that keeps stock; null elsewhere.
  final String? condition;

  /// A new item at 0 stock: still listed, but customers do not see it.
  final bool isOutOfStock;

  /// Whether the menu offers "Update stock": a new item not yet closed or sold.
  final bool canUpdateStock;
  final String? categoryIconName;
  final String? subCategoryId;
  final String? subCategoryName;
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

  /// A new item with a stock count.
  bool get keepsStock => condition == MarketplaceItemCondition.newItem;

  /// "Products › Sarees" — the category, then the sub-category when it has one.
  String get categoryLine => [categoryName, ?subCategoryName].join(' › ');

  /// "Marthandam, Kanyakumari" — the area when given, then the district.
  String get placeLine =>
      [if (area?.isNotEmpty ?? false) area!, districtName].join(', ');
}

/// What the post form sends, for a new post and an edit alike.
class MarketplacePostInput {
  const MarketplacePostInput({
    required this.categoryId,
    this.subCategoryId,
    this.condition,
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
  final String? subCategoryId;

  /// [MarketplaceItemCondition], in a category that keeps stock.
  final String? condition;
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
    'subCategoryId': subCategoryId,
    'condition': condition,
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
    this.sold = 0,
    this.categories = const [],
  });

  final int active;
  final int paused;
  final int expired;
  final int closed;
  final int sold;
  final MarketplacePlan plan;

  /// The same counts per main category posted in; a category with no posts is not listed.
  final List<MarketplaceCategoryCount> categories;

  /// Posts in [categoryId] (null: every category) with [status] (null: every status) — the
  /// numbers on the Orders › Marketplace chips, so the two rows of chips combine.
  int count({String? categoryId, String? status}) {
    if (categoryId == null) {
      return MarketplaceCategoryCount.pick(
        status,
        active: active,
        paused: paused,
        expired: expired,
        closed: closed,
        sold: sold,
      );
    }
    return categories
            .where((c) => c.categoryId == categoryId)
            .firstOrNull
            ?.of(status) ??
        0;
  }
}

/// One main category's posts by the status they show.
class MarketplaceCategoryCount {
  const MarketplaceCategoryCount({
    required this.categoryId,
    required this.active,
    required this.paused,
    required this.expired,
    required this.closed,
    this.sold = 0,
  });

  final String categoryId;
  final int active;
  final int paused;
  final int expired;
  final int closed;
  final int sold;

  int of(String? status) => pick(
    status,
    active: active,
    paused: paused,
    expired: expired,
    closed: closed,
    sold: sold,
  );

  /// The count for [status], or all of them added up when it is null.
  static int pick(
    String? status, {
    required int active,
    required int paused,
    required int expired,
    required int closed,
    required int sold,
  }) => switch (status) {
    MarketplacePostStatus.active => active,
    MarketplacePostStatus.paused => paused,
    MarketplacePostStatus.expired => expired,
    MarketplacePostStatus.closed => closed,
    MarketplacePostStatus.sold => sold,
    _ => active + paused + expired + closed + sold,
  };
}

/// A name from one of the server's reference tables, with its colour where it has one.
class MarketplaceOption {
  const MarketplaceOption({
    required this.code,
    required this.name,
    this.tone,
    this.detail,
  });

  final String code;
  final String name;
  final String? tone;

  /// A line under the name, e.g. what "Wholesale only" means.
  final String? detail;
}

/// The largest quantity until the server's own number has loaded — `Marketplace:MaxQuantity`.
const marketplaceDefaultMaxQuantity = 1000000;

/// The post kinds, statuses and limits the Marketplace screens are drawn from.
class MarketplaceOptions {
  const MarketplaceOptions({
    required this.kinds,
    required this.statuses,
    required this.imageSlots,
    this.tradeModes = const [],
    this.conditions = const [],
    required this.maxFoodOfferHours,
    required this.maxAdDays,
    this.maxQuantity = marketplaceDefaultMaxQuantity,
  });

  final List<MarketplaceOption> kinds;
  final List<MarketplaceOption> statuses;

  /// How a category may sell, named for the super admin.
  final List<MarketplaceOption> tradeModes;

  /// New and Used, with the line under each on the post form.
  final List<MarketplaceOption> conditions;
  final int imageSlots;
  final int maxFoodOfferHours;
  final int maxAdDays;

  /// The most a quantity or stock may be — `Marketplace:MaxQuantity` on the server.
  final int maxQuantity;

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

/// A main category as the super admin saves it.
class MarketplaceCategoryInput {
  const MarketplaceCategoryInput({
    required this.name,
    required this.kind,
    required this.tradeMode,
    required this.displayOrder,
    required this.isActive,
    this.shortName,
    this.description,
    this.iconName,
    this.tracksStock = false,
  });

  final String name;
  final bool tracksStock;
  final String? shortName;
  final String? description;
  final String? iconName;
  final String kind;
  final String tradeMode;
  final int displayOrder;
  final bool isActive;

  Map<String, dynamic> toJson() => {
    'name': name,
    'shortName': shortName,
    'description': description,
    'iconName': iconName,
    'kind': kind,
    'tradeMode': tradeMode,
    'tracksStock': tracksStock,
    'displayOrder': displayOrder,
    'isActive': isActive,
  };
}

/// A sub-category as the super admin saves it.
class MarketplaceSubCategoryInput {
  const MarketplaceSubCategoryInput({
    required this.name,
    required this.displayOrder,
    required this.isActive,
  });

  final String name;
  final int displayOrder;
  final bool isActive;

  Map<String, dynamic> toJson() => {
    'name': name,
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
    this.subCategoryId,
    this.unit,
  });

  /// Ask it only under this sub-category; null asks it everywhere in the category.
  final String? subCategoryId;
  final String label;
  final String fieldType;
  final List<String> options;
  final String? unit;
  final bool isRequired;
  final int displayOrder;
  final bool isActive;

  Map<String, dynamic> toJson() => {
    'subCategoryId': subCategoryId,
    'label': label,
    'fieldType': fieldType,
    'options': options,
    'unit': unit,
    'isRequired': isRequired,
    'displayOrder': displayOrder,
    'isActive': isActive,
  };
}
