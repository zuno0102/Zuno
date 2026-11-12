import 'package:json_annotation/json_annotation.dart';
import 'package:zuno/features/marketplace/domain/entities/marketplace_post.dart';

part 'marketplace_models.g.dart';

@JsonSerializable(createToJson: false)
class MarketplacePostMediaModel {
  const MarketplacePostMediaModel({required this.url, required this.sortOrder});

  factory MarketplacePostMediaModel.fromJson(Map<String, dynamic> json) =>
      _$MarketplacePostMediaModelFromJson(json);

  final String url;
  final int sortOrder;
}

@JsonSerializable(createToJson: false)
class MarketplacePostActionModel {
  const MarketplacePostActionModel({
    required this.toStatus,
    required this.name,
    required this.needsConfirm,
  });

  factory MarketplacePostActionModel.fromJson(Map<String, dynamic> json) =>
      _$MarketplacePostActionModelFromJson(json);

  final String toStatus;
  final String name;
  final bool needsConfirm;

  MarketplacePostAction toEntity() => MarketplacePostAction(
    toStatus: toStatus,
    name: name,
    needsConfirm: needsConfirm,
  );
}

@JsonSerializable(createToJson: false)
class MarketplacePostModel {
  const MarketplacePostModel({
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
    this.customDetails = const [],
    this.variants = const [],
    this.deliveryStateId,
    this.deliversEverywhere = true,
    this.deliveryDistrictIds = const [],
    this.attributes = const {},
    this.media = const [],
    this.actions = const [],
  });

  factory MarketplacePostModel.fromJson(Map<String, dynamic> json) =>
      _$MarketplacePostModelFromJson(json);

  final String id;
  final String categoryId;
  final String categoryName;
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
  final String? condition;
  final bool isOutOfStock;
  final bool canUpdateStock;
  final List<MarketplaceCustomDetailModel> customDetails;
  final List<MarketplaceVariantModel> variants;
  final String? deliveryStateId;
  final bool deliversEverywhere;
  final List<String> deliveryDistrictIds;
  final Map<String, String> attributes;
  final List<MarketplacePostMediaModel> media;
  final List<MarketplacePostActionModel> actions;

  MarketplacePost toEntity() => MarketplacePost(
    id: id,
    categoryId: categoryId,
    categoryName: categoryName,
    categoryIconName: categoryIconName,
    subCategoryId: subCategoryId,
    subCategoryName: subCategoryName,
    kind: kind,
    status: status,
    title: title,
    description: description,
    price: price,
    priceUnit: priceUnit,
    tradeType: tradeType,
    minOrderQuantity: minOrderQuantity,
    quantity: quantity,
    originalPrice: originalPrice,
    startsAt: startsAt?.toLocal(),
    endsAt: endsAt?.toLocal(),
    contactPhone: contactPhone,
    districtId: districtId,
    districtName: districtName,
    stateId: stateId,
    stateName: stateName,
    area: area,
    latitude: latitude,
    longitude: longitude,
    condition: condition,
    isOutOfStock: isOutOfStock,
    canUpdateStock: canUpdateStock,
    customDetails: [for (final d in customDetails) d.toEntity()],
    variants: [for (final v in variants) v.toEntity()],
    deliveryStateId: deliveryStateId,
    deliversEverywhere: deliversEverywhere,
    deliveryDistrictIds: deliveryDistrictIds,
    attributes: attributes,
    imageUrls: {for (final m in media) m.sortOrder: m.url},
    actions: [for (final a in actions) a.toEntity()],
  );
}

@JsonSerializable(createToJson: false)
class MarketplaceCustomDetailModel {
  const MarketplaceCustomDetailModel({required this.name, required this.value});

  factory MarketplaceCustomDetailModel.fromJson(Map<String, dynamic> json) =>
      _$MarketplaceCustomDetailModelFromJson(json);

  final String name;
  final String value;

  MarketplaceCustomDetail toEntity() =>
      MarketplaceCustomDetail(name: name, value: value);
}

@JsonSerializable(createToJson: false)
class MarketplaceVariantModel {
  const MarketplaceVariantModel({
    required this.id,
    required this.stock,
    this.colour,
    this.size,
    this.price,
  });

  factory MarketplaceVariantModel.fromJson(Map<String, dynamic> json) =>
      _$MarketplaceVariantModelFromJson(json);

  final String id;
  final String? colour;
  final String? size;
  final double? price;
  final int stock;

  MarketplaceVariant toEntity() => MarketplaceVariant(
    id: id,
    colour: colour,
    size: size,
    price: price,
    stock: stock,
  );
}

@JsonSerializable(createToJson: false)
class MarketplacePostPageModel {
  const MarketplacePostPageModel({required this.items});

  factory MarketplacePostPageModel.fromJson(Map<String, dynamic> json) =>
      _$MarketplacePostPageModelFromJson(json);

  final List<MarketplacePostModel> items;
}

@JsonSerializable(createToJson: false)
class MarketplaceCategoryFieldModel {
  const MarketplaceCategoryFieldModel({
    required this.id,
    required this.key,
    required this.label,
    required this.fieldType,
    required this.isRequired,
    required this.displayOrder,
    required this.isActive,
    this.options = const [],
    this.subCategoryId,
    this.unit,
  });

  factory MarketplaceCategoryFieldModel.fromJson(Map<String, dynamic> json) =>
      _$MarketplaceCategoryFieldModelFromJson(json);

  final String id;
  final String? subCategoryId;
  final String key;
  final String label;
  final String fieldType;
  final List<String> options;
  final String? unit;
  final bool isRequired;
  final int displayOrder;
  final bool isActive;

  MarketplaceCategoryField toEntity() => MarketplaceCategoryField(
    id: id,
    subCategoryId: subCategoryId,
    key: key,
    label: label,
    fieldType: fieldType,
    options: options,
    unit: unit,
    isRequired: isRequired,
    displayOrder: displayOrder,
    isActive: isActive,
  );
}

@JsonSerializable(createToJson: false)
class MarketplaceCategoryModel {
  const MarketplaceCategoryModel({
    required this.id,
    required this.name,
    required this.slug,
    required this.kind,
    required this.tradeMode,
    this.tracksStock = false,
    required this.displayOrder,
    required this.isActive,
    this.shortName,
    this.description,
    this.iconName,
    this.subCategories = const [],
    this.fields = const [],
  });

  factory MarketplaceCategoryModel.fromJson(Map<String, dynamic> json) =>
      _$MarketplaceCategoryModelFromJson(json);

  final String id;
  final String name;
  final String? shortName;
  final String? description;
  final String slug;
  final String? iconName;
  final String kind;
  final String tradeMode;
  final bool tracksStock;
  final int displayOrder;
  final bool isActive;
  final List<MarketplaceSubCategoryModel> subCategories;
  final List<MarketplaceCategoryFieldModel> fields;

  MarketplaceCategory toEntity() => MarketplaceCategory(
    id: id,
    name: name,
    shortName: shortName?.isNotEmpty ?? false ? shortName! : name,
    description: description,
    slug: slug,
    iconName: iconName,
    kind: kind,
    tradeMode: tradeMode,
    tracksStock: tracksStock,
    displayOrder: displayOrder,
    isActive: isActive,
    subCategories: [for (final s in subCategories) s.toEntity()],
    fields: [for (final f in fields) f.toEntity()],
  );
}

@JsonSerializable(createToJson: false)
class MarketplaceSubCategoryModel {
  const MarketplaceSubCategoryModel({
    required this.id,
    required this.name,
    required this.slug,
    required this.displayOrder,
    required this.isActive,
    this.iconName,
  });

  factory MarketplaceSubCategoryModel.fromJson(Map<String, dynamic> json) =>
      _$MarketplaceSubCategoryModelFromJson(json);

  final String id;
  final String name;
  final String slug;
  final String? iconName;
  final int displayOrder;
  final bool isActive;

  MarketplaceSubCategory toEntity() => MarketplaceSubCategory(
    id: id,
    name: name,
    slug: slug,
    iconName: iconName,
    displayOrder: displayOrder,
    isActive: isActive,
  );
}

@JsonSerializable(createToJson: false)
class MarketplacePlanModel {
  const MarketplacePlanModel({
    required this.code,
    required this.name,
    required this.price,
    required this.maxActivePosts,
    required this.usedActivePosts,
    this.endsAt,
  });

  factory MarketplacePlanModel.fromJson(Map<String, dynamic> json) =>
      _$MarketplacePlanModelFromJson(json);

  final String code;
  final String name;
  final double price;
  final int maxActivePosts;
  final int usedActivePosts;
  final DateTime? endsAt;

  MarketplacePlan toEntity() => MarketplacePlan(
    code: code,
    name: name,
    price: price,
    maxActivePosts: maxActivePosts,
    usedActivePosts: usedActivePosts,
    endsAt: endsAt?.toLocal(),
  );
}

@JsonSerializable(createToJson: false)
class MarketplaceSummaryModel {
  const MarketplaceSummaryModel({
    required this.active,
    required this.paused,
    required this.expired,
    required this.closed,
    this.sold = 0,
    required this.plan,
    this.categories = const [],
  });

  factory MarketplaceSummaryModel.fromJson(Map<String, dynamic> json) =>
      _$MarketplaceSummaryModelFromJson(json);

  final int active;
  final int paused;
  final int expired;
  final int closed;
  final int sold;
  final MarketplacePlanModel plan;
  final List<MarketplaceCategoryCountModel> categories;

  MarketplaceSummary toEntity() => MarketplaceSummary(
    active: active,
    paused: paused,
    expired: expired,
    closed: closed,
    sold: sold,
    plan: plan.toEntity(),
    categories: [for (final c in categories) c.toEntity()],
  );
}

@JsonSerializable(createToJson: false)
class MarketplaceCategoryCountModel {
  const MarketplaceCategoryCountModel({
    required this.categoryId,
    required this.active,
    required this.paused,
    required this.expired,
    required this.closed,
    this.sold = 0,
  });

  factory MarketplaceCategoryCountModel.fromJson(Map<String, dynamic> json) =>
      _$MarketplaceCategoryCountModelFromJson(json);

  final String categoryId;
  final int active;
  final int paused;
  final int expired;
  final int closed;
  final int sold;

  MarketplaceCategoryCount toEntity() => MarketplaceCategoryCount(
    categoryId: categoryId,
    active: active,
    paused: paused,
    expired: expired,
    closed: closed,
    sold: sold,
  );
}

@JsonSerializable(createToJson: false)
class MarketplaceOptionModel {
  const MarketplaceOptionModel({
    required this.code,
    required this.name,
    this.tone,
    this.detail,
  });

  factory MarketplaceOptionModel.fromJson(Map<String, dynamic> json) =>
      _$MarketplaceOptionModelFromJson(json);

  final String code;
  final String name;
  final String? tone;
  final String? detail;

  MarketplaceOption toEntity() =>
      MarketplaceOption(code: code, name: name, tone: tone, detail: detail);
}

@JsonSerializable(createToJson: false)
class MarketplaceOptionsModel {
  const MarketplaceOptionsModel({
    required this.kinds,
    required this.statuses,
    required this.imageSlots,
    required this.maxFoodOfferHours,
    this.tradeModes = const [],
    this.conditions = const [],
    required this.maxAdDays,
    this.maxQuantity = marketplaceDefaultMaxQuantity,
  });

  factory MarketplaceOptionsModel.fromJson(Map<String, dynamic> json) =>
      _$MarketplaceOptionsModelFromJson(json);

  final List<MarketplaceOptionModel> kinds;
  final List<MarketplaceOptionModel> statuses;
  final List<MarketplaceOptionModel> tradeModes;
  final List<MarketplaceOptionModel> conditions;
  final int imageSlots;
  final int maxFoodOfferHours;
  final int maxAdDays;
  final int maxQuantity;

  MarketplaceOptions toEntity() => MarketplaceOptions(
    kinds: [for (final k in kinds) k.toEntity()],
    statuses: [for (final s in statuses) s.toEntity()],
    tradeModes: [for (final t in tradeModes) t.toEntity()],
    conditions: [for (final c in conditions) c.toEntity()],
    imageSlots: imageSlots,
    maxFoodOfferHours: maxFoodOfferHours,
    maxAdDays: maxAdDays,
    maxQuantity: maxQuantity,
  );
}

@JsonSerializable(createToJson: false)
class MarketplaceBusinessModel {
  const MarketplaceBusinessModel({
    required this.name,
    required this.isVerified,
    required this.isKnown,
  });

  factory MarketplaceBusinessModel.fromJson(Map<String, dynamic> json) =>
      _$MarketplaceBusinessModelFromJson(json);

  final String name;
  final bool isVerified;
  final bool isKnown;

  MarketplaceBusiness toEntity() =>
      MarketplaceBusiness(name: name, isVerified: isVerified, isKnown: isKnown);
}
