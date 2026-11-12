// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'marketplace_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

MarketplacePostMediaModel _$MarketplacePostMediaModelFromJson(
  Map<String, dynamic> json,
) => MarketplacePostMediaModel(
  url: json['url'] as String,
  sortOrder: (json['sortOrder'] as num).toInt(),
);

MarketplacePostActionModel _$MarketplacePostActionModelFromJson(
  Map<String, dynamic> json,
) => MarketplacePostActionModel(
  toStatus: json['toStatus'] as String,
  name: json['name'] as String,
  needsConfirm: json['needsConfirm'] as bool,
);

MarketplacePostModel _$MarketplacePostModelFromJson(
  Map<String, dynamic> json,
) => MarketplacePostModel(
  id: json['id'] as String,
  categoryId: json['categoryId'] as String,
  categoryName: json['categoryName'] as String,
  kind: json['kind'] as String,
  status: json['status'] as String,
  title: json['title'] as String,
  tradeType: json['tradeType'] as String,
  districtId: json['districtId'] as String,
  districtName: json['districtName'] as String,
  stateId: json['stateId'] as String,
  stateName: json['stateName'] as String,
  categoryIconName: json['categoryIconName'] as String?,
  subCategoryId: json['subCategoryId'] as String?,
  subCategoryName: json['subCategoryName'] as String?,
  description: json['description'] as String?,
  price: (json['price'] as num?)?.toDouble(),
  priceUnit: json['priceUnit'] as String?,
  minOrderQuantity: (json['minOrderQuantity'] as num?)?.toInt(),
  quantity: (json['quantity'] as num?)?.toInt(),
  originalPrice: (json['originalPrice'] as num?)?.toDouble(),
  startsAt: json['startsAt'] == null
      ? null
      : DateTime.parse(json['startsAt'] as String),
  endsAt: json['endsAt'] == null
      ? null
      : DateTime.parse(json['endsAt'] as String),
  contactPhone: json['contactPhone'] as String?,
  area: json['area'] as String?,
  latitude: (json['latitude'] as num?)?.toDouble(),
  longitude: (json['longitude'] as num?)?.toDouble(),
  condition: json['condition'] as String?,
  isOutOfStock: json['isOutOfStock'] as bool? ?? false,
  canUpdateStock: json['canUpdateStock'] as bool? ?? false,
  customDetails:
      (json['customDetails'] as List<dynamic>?)
          ?.map(
            (e) => MarketplaceCustomDetailModel.fromJson(
              e as Map<String, dynamic>,
            ),
          )
          .toList() ??
      const [],
  variants:
      (json['variants'] as List<dynamic>?)
          ?.map(
            (e) => MarketplaceVariantModel.fromJson(e as Map<String, dynamic>),
          )
          .toList() ??
      const [],
  deliveryStateId: json['deliveryStateId'] as String?,
  deliversEverywhere: json['deliversEverywhere'] as bool? ?? true,
  deliveryDistrictIds:
      (json['deliveryDistrictIds'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList() ??
      const [],
  attributes:
      (json['attributes'] as Map<String, dynamic>?)?.map(
        (k, e) => MapEntry(k, e as String),
      ) ??
      const {},
  media:
      (json['media'] as List<dynamic>?)
          ?.map(
            (e) =>
                MarketplacePostMediaModel.fromJson(e as Map<String, dynamic>),
          )
          .toList() ??
      const [],
  actions:
      (json['actions'] as List<dynamic>?)
          ?.map(
            (e) =>
                MarketplacePostActionModel.fromJson(e as Map<String, dynamic>),
          )
          .toList() ??
      const [],
);

MarketplaceCustomDetailModel _$MarketplaceCustomDetailModelFromJson(
  Map<String, dynamic> json,
) => MarketplaceCustomDetailModel(
  name: json['name'] as String,
  value: json['value'] as String,
);

MarketplaceVariantModel _$MarketplaceVariantModelFromJson(
  Map<String, dynamic> json,
) => MarketplaceVariantModel(
  id: json['id'] as String,
  stock: (json['stock'] as num).toInt(),
  colour: json['colour'] as String?,
  size: json['size'] as String?,
  price: (json['price'] as num?)?.toDouble(),
);

MarketplacePostPageModel _$MarketplacePostPageModelFromJson(
  Map<String, dynamic> json,
) => MarketplacePostPageModel(
  items: (json['items'] as List<dynamic>)
      .map((e) => MarketplacePostModel.fromJson(e as Map<String, dynamic>))
      .toList(),
);

MarketplaceCategoryFieldModel _$MarketplaceCategoryFieldModelFromJson(
  Map<String, dynamic> json,
) => MarketplaceCategoryFieldModel(
  id: json['id'] as String,
  key: json['key'] as String,
  label: json['label'] as String,
  fieldType: json['fieldType'] as String,
  isRequired: json['isRequired'] as bool,
  displayOrder: (json['displayOrder'] as num).toInt(),
  isActive: json['isActive'] as bool,
  options:
      (json['options'] as List<dynamic>?)?.map((e) => e as String).toList() ??
      const [],
  subCategoryId: json['subCategoryId'] as String?,
  unit: json['unit'] as String?,
);

MarketplaceCategoryModel _$MarketplaceCategoryModelFromJson(
  Map<String, dynamic> json,
) => MarketplaceCategoryModel(
  id: json['id'] as String,
  name: json['name'] as String,
  slug: json['slug'] as String,
  kind: json['kind'] as String,
  tradeMode: json['tradeMode'] as String,
  tracksStock: json['tracksStock'] as bool? ?? false,
  displayOrder: (json['displayOrder'] as num).toInt(),
  isActive: json['isActive'] as bool,
  shortName: json['shortName'] as String?,
  description: json['description'] as String?,
  iconName: json['iconName'] as String?,
  subCategories:
      (json['subCategories'] as List<dynamic>?)
          ?.map(
            (e) =>
                MarketplaceSubCategoryModel.fromJson(e as Map<String, dynamic>),
          )
          .toList() ??
      const [],
  fields:
      (json['fields'] as List<dynamic>?)
          ?.map(
            (e) => MarketplaceCategoryFieldModel.fromJson(
              e as Map<String, dynamic>,
            ),
          )
          .toList() ??
      const [],
);

MarketplaceSubCategoryModel _$MarketplaceSubCategoryModelFromJson(
  Map<String, dynamic> json,
) => MarketplaceSubCategoryModel(
  id: json['id'] as String,
  name: json['name'] as String,
  slug: json['slug'] as String,
  displayOrder: (json['displayOrder'] as num).toInt(),
  isActive: json['isActive'] as bool,
  iconName: json['iconName'] as String?,
  colourOptions:
      (json['colourOptions'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList() ??
      const [],
  sizeOptions:
      (json['sizeOptions'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList() ??
      const [],
);

MarketplacePlanModel _$MarketplacePlanModelFromJson(
  Map<String, dynamic> json,
) => MarketplacePlanModel(
  code: json['code'] as String,
  name: json['name'] as String,
  price: (json['price'] as num).toDouble(),
  maxActivePosts: (json['maxActivePosts'] as num).toInt(),
  usedActivePosts: (json['usedActivePosts'] as num).toInt(),
  endsAt: json['endsAt'] == null
      ? null
      : DateTime.parse(json['endsAt'] as String),
);

MarketplaceSummaryModel _$MarketplaceSummaryModelFromJson(
  Map<String, dynamic> json,
) => MarketplaceSummaryModel(
  active: (json['active'] as num).toInt(),
  paused: (json['paused'] as num).toInt(),
  expired: (json['expired'] as num).toInt(),
  closed: (json['closed'] as num).toInt(),
  sold: (json['sold'] as num?)?.toInt() ?? 0,
  plan: MarketplacePlanModel.fromJson(json['plan'] as Map<String, dynamic>),
  categories:
      (json['categories'] as List<dynamic>?)
          ?.map(
            (e) => MarketplaceCategoryCountModel.fromJson(
              e as Map<String, dynamic>,
            ),
          )
          .toList() ??
      const [],
);

MarketplaceCategoryCountModel _$MarketplaceCategoryCountModelFromJson(
  Map<String, dynamic> json,
) => MarketplaceCategoryCountModel(
  categoryId: json['categoryId'] as String,
  active: (json['active'] as num).toInt(),
  paused: (json['paused'] as num).toInt(),
  expired: (json['expired'] as num).toInt(),
  closed: (json['closed'] as num).toInt(),
  sold: (json['sold'] as num?)?.toInt() ?? 0,
);

MarketplaceOptionModel _$MarketplaceOptionModelFromJson(
  Map<String, dynamic> json,
) => MarketplaceOptionModel(
  code: json['code'] as String,
  name: json['name'] as String,
  tone: json['tone'] as String?,
  detail: json['detail'] as String?,
);

MarketplaceOptionsModel _$MarketplaceOptionsModelFromJson(
  Map<String, dynamic> json,
) => MarketplaceOptionsModel(
  kinds: (json['kinds'] as List<dynamic>)
      .map((e) => MarketplaceOptionModel.fromJson(e as Map<String, dynamic>))
      .toList(),
  statuses: (json['statuses'] as List<dynamic>)
      .map((e) => MarketplaceOptionModel.fromJson(e as Map<String, dynamic>))
      .toList(),
  imageSlots: (json['imageSlots'] as num).toInt(),
  maxFoodOfferHours: (json['maxFoodOfferHours'] as num).toInt(),
  tradeModes:
      (json['tradeModes'] as List<dynamic>?)
          ?.map(
            (e) => MarketplaceOptionModel.fromJson(e as Map<String, dynamic>),
          )
          .toList() ??
      const [],
  conditions:
      (json['conditions'] as List<dynamic>?)
          ?.map(
            (e) => MarketplaceOptionModel.fromJson(e as Map<String, dynamic>),
          )
          .toList() ??
      const [],
  maxAdDays: (json['maxAdDays'] as num).toInt(),
  maxQuantity:
      (json['maxQuantity'] as num?)?.toInt() ?? marketplaceDefaultMaxQuantity,
  maxStartDaysAhead:
      (json['maxStartDaysAhead'] as num?)?.toInt() ??
      MarketplaceTextLimits.fallbackStartDaysAhead,
  textLimits: json['textLimits'] == null
      ? const MarketplaceTextLimits()
      : marketplaceTextLimitsFromJson(
          json['textLimits'] as Map<String, dynamic>,
        ),
);

MarketplaceBusinessModel _$MarketplaceBusinessModelFromJson(
  Map<String, dynamic> json,
) => MarketplaceBusinessModel(
  name: json['name'] as String,
  isVerified: json['isVerified'] as bool,
  isKnown: json['isKnown'] as bool,
);
