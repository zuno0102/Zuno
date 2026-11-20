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

  /// The usual price (a product's MRP, a food offer's price before), shown struck through.
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

  /// Whole percent below the usual price, e.g. 40; null when there is no saving.
  int? get percentOff {
    final was = originalPrice;
    final now = price;
    if (was == null || now == null || was <= 0 || now >= was) return null;
    return ((was - now) * 100 / was).floor();
  }

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

/// How the app draws a home section.
enum MarketplaceHomeLayout {
  /// Two cards across.
  grid,

  /// Poster banners that move on by themselves.
  banner,

  /// One row, swiped sideways.
  strip,

  /// Two across, loading more as the customer scrolls.
  feed;

  /// The server's name; an unknown one (from a newer server) is drawn as a strip.
  static MarketplaceHomeLayout parse(String value) => values.firstWhere(
    (l) => l.name == value.toLowerCase(),
    orElse: () => strip,
  );
}

/// One section of the home, as the server lists them: a heading, a layout and its cards. A feed
/// comes without cards; the app pages it.
class MarketplaceHomeSection {
  const MarketplaceHomeSection({
    required this.code,
    required this.layout,
    this.title = '',
    this.pageSize = 20,
    this.items = const [],
  });

  final String code;
  final String title;
  final MarketplaceHomeLayout layout;
  final int pageSize;
  final List<MarketplaceCard> items;
}

/// The customer's Marketplace home: its sections top to bottom, each with something to show.
class MarketplaceHome {
  const MarketplaceHome({this.sections = const []});

  final List<MarketplaceHomeSection> sections;

  /// Nothing on show anywhere: the feed alone would be empty too.
  bool get isEmpty => sections.every((s) => s.items.isEmpty);
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
