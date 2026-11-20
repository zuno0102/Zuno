import 'package:json_annotation/json_annotation.dart';
import 'package:zuno/features/marketplace/data/models/marketplace_models.dart';
import 'package:zuno/features/marketplace/domain/entities/marketplace_customer.dart';

part 'marketplace_customer_models.g.dart';

@JsonSerializable(createToJson: false)
class MarketplaceCardModel {
  const MarketplaceCardModel({
    required this.id,
    required this.kind,
    required this.title,
    required this.categoryId,
    required this.categoryName,
    required this.tradeType,
    required this.districtName,
    required this.businessName,
    this.subCategoryName,
    this.price,
    this.originalPrice,
    this.priceUnit,
    this.minOrderQuantity,
    this.quantity,
    this.condition,
    this.imageUrl,
    this.area,
    this.startsAt,
    this.endsAt,
    this.latitude,
    this.longitude,
    this.distanceKm,
    this.isFavourite = false,
    this.isAvailable = true,
  });

  factory MarketplaceCardModel.fromJson(Map<String, dynamic> json) =>
      _$MarketplaceCardModelFromJson(json);

  final String id;
  final String kind;
  final String title;
  final String categoryId;
  final String categoryName;
  final String? subCategoryName;
  final double? price;
  final double? originalPrice;
  final String? priceUnit;
  final String tradeType;
  final int? minOrderQuantity;
  final int? quantity;
  final String? condition;
  final String? imageUrl;
  final String? area;
  final String districtName;
  final String businessName;
  final DateTime? startsAt;
  final DateTime? endsAt;
  final double? latitude;
  final double? longitude;
  final double? distanceKm;
  final bool isFavourite;
  final bool isAvailable;

  MarketplaceCard toEntity() => MarketplaceCard(
    id: id,
    kind: kind,
    title: title,
    categoryId: categoryId,
    categoryName: categoryName,
    subCategoryName: subCategoryName,
    price: price,
    originalPrice: originalPrice,
    priceUnit: priceUnit,
    tradeType: tradeType,
    minOrderQuantity: minOrderQuantity,
    quantity: quantity,
    condition: condition,
    imageUrl: imageUrl,
    area: area,
    districtName: districtName,
    businessName: businessName,
    startsAt: startsAt?.toLocal(),
    endsAt: endsAt?.toLocal(),
    latitude: latitude,
    longitude: longitude,
    distanceKm: distanceKm,
    isFavourite: isFavourite,
    isAvailable: isAvailable,
  );
}

List<MarketplaceCard> _cards(List<MarketplaceCardModel> models) => [
  for (final c in models) c.toEntity(),
];

@JsonSerializable(createToJson: false)
class MarketplaceCardPageModel {
  const MarketplaceCardPageModel({this.items = const [], this.totalCount = 0});

  factory MarketplaceCardPageModel.fromJson(Map<String, dynamic> json) =>
      _$MarketplaceCardPageModelFromJson(json);

  final List<MarketplaceCardModel> items;
  final int totalCount;

  MarketplaceCardPage toEntity() =>
      MarketplaceCardPage(items: _cards(items), totalCount: totalCount);
}

@JsonSerializable(createToJson: false)
class MarketplaceHomeModel {
  const MarketplaceHomeModel({
    this.banners = const [],
    this.food = const [],
    this.products = const [],
    this.wholesale = const [],
  });

  factory MarketplaceHomeModel.fromJson(Map<String, dynamic> json) =>
      _$MarketplaceHomeModelFromJson(json);

  final List<MarketplaceCardModel> banners;
  final List<MarketplaceCardModel> food;
  final List<MarketplaceCardModel> products;
  final List<MarketplaceCardModel> wholesale;

  MarketplaceHome toEntity() => MarketplaceHome(
    banners: _cards(banners),
    food: _cards(food),
    products: _cards(products),
    wholesale: _cards(wholesale),
  );
}

@JsonSerializable(createToJson: false)
class MarketplacePostDetailModel {
  const MarketplacePostDetailModel({
    required this.card,
    this.description,
    this.packQuantity,
    this.details = const [],
    this.variants = const [],
    this.media = const [],
    this.contactPhone,
    this.businessLogoUrl,
    this.paymentMethods = const [],
    this.canOrder = false,
    this.canRequest = false,
    this.deliversEverywhere = true,
    this.deliveryStateName,
    this.deliveryDistrictNames = const [],
  });

  factory MarketplacePostDetailModel.fromJson(Map<String, dynamic> json) =>
      _$MarketplacePostDetailModelFromJson(json);

  final MarketplaceCardModel card;
  final String? description;
  final int? packQuantity;
  final List<MarketplaceCustomDetailModel> details;
  final List<MarketplaceVariantModel> variants;
  final List<MarketplacePostMediaModel> media;
  final String? contactPhone;
  final String? businessLogoUrl;
  final List<MarketplaceOptionModel> paymentMethods;
  final bool canOrder;
  final bool canRequest;
  final bool deliversEverywhere;
  final String? deliveryStateName;
  final List<String> deliveryDistrictNames;

  MarketplacePostDetail toEntity() => MarketplacePostDetail(
    card: card.toEntity(),
    description: description,
    packQuantity: packQuantity,
    details: [for (final d in details) (name: d.name, value: d.value)],
    variants: [for (final v in variants) v.toEntity()],
    media: [
      for (final m in [...media]..sort((a, b) => a.sortOrder - b.sortOrder))
        m.url,
    ],
    contactPhone: contactPhone,
    businessLogoUrl: businessLogoUrl,
    paymentMethods: [for (final m in paymentMethods) m.toEntity()],
    canOrder: canOrder,
    canRequest: canRequest,
    deliversEverywhere: deliversEverywhere,
    deliveryStateName: deliveryStateName,
    deliveryDistrictNames: deliveryDistrictNames,
  );
}
