// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'marketplace_customer_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

MarketplaceCardModel _$MarketplaceCardModelFromJson(
  Map<String, dynamic> json,
) => MarketplaceCardModel(
  id: json['id'] as String,
  kind: json['kind'] as String,
  title: json['title'] as String,
  categoryId: json['categoryId'] as String,
  categoryName: json['categoryName'] as String,
  tradeType: json['tradeType'] as String,
  districtName: json['districtName'] as String,
  businessName: json['businessName'] as String,
  subCategoryName: json['subCategoryName'] as String?,
  price: (json['price'] as num?)?.toDouble(),
  originalPrice: (json['originalPrice'] as num?)?.toDouble(),
  priceUnit: json['priceUnit'] as String?,
  minOrderQuantity: (json['minOrderQuantity'] as num?)?.toInt(),
  quantity: (json['quantity'] as num?)?.toInt(),
  condition: json['condition'] as String?,
  imageUrl: json['imageUrl'] as String?,
  area: json['area'] as String?,
  startsAt: json['startsAt'] == null
      ? null
      : DateTime.parse(json['startsAt'] as String),
  endsAt: json['endsAt'] == null
      ? null
      : DateTime.parse(json['endsAt'] as String),
  latitude: (json['latitude'] as num?)?.toDouble(),
  longitude: (json['longitude'] as num?)?.toDouble(),
  distanceKm: (json['distanceKm'] as num?)?.toDouble(),
  isFavourite: json['isFavourite'] as bool? ?? false,
  isAvailable: json['isAvailable'] as bool? ?? true,
);

MarketplaceCardPageModel _$MarketplaceCardPageModelFromJson(
  Map<String, dynamic> json,
) => MarketplaceCardPageModel(
  items:
      (json['items'] as List<dynamic>?)
          ?.map((e) => MarketplaceCardModel.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
  totalCount: (json['totalCount'] as num?)?.toInt() ?? 0,
);

MarketplaceHomeModel _$MarketplaceHomeModelFromJson(
  Map<String, dynamic> json,
) => MarketplaceHomeModel(
  banners:
      (json['banners'] as List<dynamic>?)
          ?.map((e) => MarketplaceCardModel.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
  food:
      (json['food'] as List<dynamic>?)
          ?.map((e) => MarketplaceCardModel.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
  products:
      (json['products'] as List<dynamic>?)
          ?.map((e) => MarketplaceCardModel.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
  wholesale:
      (json['wholesale'] as List<dynamic>?)
          ?.map((e) => MarketplaceCardModel.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
);

MarketplacePostDetailModel _$MarketplacePostDetailModelFromJson(
  Map<String, dynamic> json,
) => MarketplacePostDetailModel(
  card: MarketplaceCardModel.fromJson(json['card'] as Map<String, dynamic>),
  description: json['description'] as String?,
  packQuantity: (json['packQuantity'] as num?)?.toInt(),
  details:
      (json['details'] as List<dynamic>?)
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
  media:
      (json['media'] as List<dynamic>?)
          ?.map(
            (e) =>
                MarketplacePostMediaModel.fromJson(e as Map<String, dynamic>),
          )
          .toList() ??
      const [],
  contactPhone: json['contactPhone'] as String?,
  businessLogoUrl: json['businessLogoUrl'] as String?,
  paymentMethods:
      (json['paymentMethods'] as List<dynamic>?)
          ?.map(
            (e) => MarketplaceOptionModel.fromJson(e as Map<String, dynamic>),
          )
          .toList() ??
      const [],
  canOrder: json['canOrder'] as bool? ?? false,
  canRequest: json['canRequest'] as bool? ?? false,
  deliversEverywhere: json['deliversEverywhere'] as bool? ?? true,
  deliveryStateName: json['deliveryStateName'] as String?,
  deliveryDistrictNames:
      (json['deliveryDistrictNames'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList() ??
      const [],
);
