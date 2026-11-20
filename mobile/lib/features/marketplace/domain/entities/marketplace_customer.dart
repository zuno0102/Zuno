import 'package:zuno/features/marketplace/domain/entities/marketplace_post.dart';

/// A post on a customer's card: photo, price, where, who sells it, and whether it is saved.
class MarketplaceCard {
  const MarketplaceCard({
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

  final String id;

  /// `Listing`, `FoodOffer` or `Advertisement`.
  final String kind;
  final String title;
  final String categoryId;
  final String categoryName;
  final String? subCategoryName;
  final double? price;

  /// A food offer's usual price, shown struck through.
  final double? originalPrice;
  final String? priceUnit;

  /// `Retail` or `Wholesale` (a B2B lot).
  final String tradeType;
  final int? minOrderQuantity;

  /// Stock left, portions left, or the lot's quantity; null when not stated.
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

  /// False on a wishlist card whose post is no longer on show.
  final bool isAvailable;

  bool get isWholesale => tradeType == 'Wholesale';

  bool get isFood => kind == 'FoodOffer';

  bool get isAd => kind == 'Advertisement';

  bool get hasPlace => latitude != null && longitude != null;

  /// "Marthandam, Kanyakumari".
  String get placeName => area == null || area!.trim().isEmpty
      ? districtName
      : '$area, $districtName';

  MarketplaceCard copyWith({bool? isFavourite}) => MarketplaceCard(
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
    startsAt: startsAt,
    endsAt: endsAt,
    latitude: latitude,
    longitude: longitude,
    distanceKm: distanceKm,
    isFavourite: isFavourite ?? this.isFavourite,
    isAvailable: isAvailable,
  );
}

class MarketplaceCardPage {
  const MarketplaceCardPage({required this.items, required this.totalCount});

  final List<MarketplaceCard> items;
  final int totalCount;
}

/// The customer's Marketplace home: advert banners, food near them, products and B2B lots.
class MarketplaceHome {
  const MarketplaceHome({
    this.banners = const [],
    this.food = const [],
    this.products = const [],
    this.wholesale = const [],
  });

  final List<MarketplaceCard> banners;
  final List<MarketplaceCard> food;
  final List<MarketplaceCard> products;
  final List<MarketplaceCard> wholesale;

  bool get isEmpty =>
      banners.isEmpty && food.isEmpty && products.isEmpty && wholesale.isEmpty;
}

/// A label and its value, e.g. "Fabric: Silk".
typedef MarketplaceDetail = ({String name, String value});

/// A post as a customer opens it.
class MarketplacePostDetail {
  const MarketplacePostDetail({
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

  final MarketplaceCard card;
  final String? description;
  final int? packQuantity;
  final List<MarketplaceDetail> details;

  /// The colours / sizes on sale, the main one first.
  final List<MarketplaceVariant> variants;

  /// The post's own photos, in slot order.
  final List<String> media;
  final String? contactPhone;
  final String? businessLogoUrl;

  /// How the seller takes payment now (online only while it can be taken).
  final List<MarketplaceOption> paymentMethods;

  /// A product: bought in the app.
  final bool canOrder;

  /// A B2B lot: asked for with a request.
  final bool canRequest;
  final bool deliversEverywhere;
  final String? deliveryStateName;
  final List<String> deliveryDistrictNames;

  /// "All of India", "All of Tamil Nadu", "Kanyakumari, Tirunelveli".
  String get deliversTo {
    if (deliversEverywhere) return 'All of India';
    if (deliveryDistrictNames.isNotEmpty) {
      return deliveryDistrictNames.join(', ');
    }
    return deliveryStateName == null
        ? 'All of India'
        : 'All of $deliveryStateName';
  }
}
