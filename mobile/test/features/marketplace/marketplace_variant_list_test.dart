import 'package:flutter_test/flutter_test.dart';
import 'package:zuno/features/marketplace/domain/entities/marketplace_post.dart';
import 'package:zuno/features/marketplace/presentation/widgets/marketplace_post_lines.dart';
import 'package:zuno/features/marketplace/presentation/widgets/marketplace_product_sections.dart';

MarketplacePost _shirt({
  double price = 449,
  double? mrp,
  List<MarketplaceVariant> variants = const [],
}) => MarketplacePost(
  id: 'p-1',
  categoryId: 'cat-products',
  categoryName: 'Products',
  kind: MarketplacePostKind.listing,
  status: MarketplacePostStatus.active,
  title: 'Cotton shirt',
  condition: MarketplaceItemCondition.newItem,
  price: price,
  originalPrice: mrp,
  tradeType: MarketplaceTradeType.retail,
  districtId: 'd-kk',
  districtName: 'Kanyakumari',
  stateId: 's-tn',
  stateName: 'Tamil Nadu',
  attributes: const {},
  imageUrls: const {},
  actions: const [],
  variants: variants,
);

void main() {
  group('MarketplaceVariantList', () {
    test('starts from the saved variants, a missing price taken from the '
        'post', () {
      final list = MarketplaceVariantList(const [
        MarketplaceVariant(id: 'v1', colour: 'Red', size: 'M', stock: 3),
        MarketplaceVariant(id: 'v2', colour: 'Blue', stock: 2, price: 499),
      ], price: 449);
      addTearDown(list.dispose);

      expect(
        [for (final v in list.items) (v.id, v.name, v.price, v.stock)],
        [('v1', 'Red · M', 449.0, 3), ('v2', 'Blue', 499.0, 2)],
      );
      expect(list.totalStock, 5);
      expect(list.highestPrice, 499);
    });

    test('adds, replaces and removes, telling the form each time', () {
      final list = MarketplaceVariantList(const []);
      addTearDown(list.dispose);
      var told = 0;
      list.addListener(() => told++);

      list
        ..put(const MarketplaceVariant(colour: 'Red', stock: 4, price: 499))
        ..put(const MarketplaceVariant(colour: 'Green', stock: 1, price: 449))
        ..put(
          const MarketplaceVariant(colour: 'Maroon', stock: 6, price: 499),
          at: 0,
        )
        ..removeAt(1);

      expect([for (final v in list.items) v.name], ['Maroon']);
      expect(list.totalStock, 6);
      expect(told, 4);
    });

    test('an empty list has no quantity and no dearest price', () {
      final list = MarketplaceVariantList(const []);
      addTearDown(list.dispose);

      expect(
        (list.isEmpty, list.totalStock, list.highestPrice),
        (true, 0, null),
      );
    });
  });

  group('marketplaceOfferPercent', () {
    test('is how far under the MRP the price is, in whole per cent', () {
      expect(marketplaceOfferPercent(449, 599), 25);
      expect(marketplaceOfferPercent(200, 350), 43);
    });

    test('says nothing without an MRP, or at or above it', () {
      expect(marketplaceOfferPercent(449, null), isNull);
      expect(marketplaceOfferPercent(599, 599), isNull);
      expect(marketplaceOfferPercent(650, 599), isNull);
      expect(marketplaceOfferPercent(null, 599), isNull);
    });
  });

  group('marketplacePriceLine', () {
    test('variants priced apart show the range', () {
      expect(
        marketplacePriceLine(
          _shirt(
            variants: const [
              MarketplaceVariant(colour: 'Red', stock: 1, price: 499),
              MarketplaceVariant(colour: 'Green', stock: 1, price: 449),
            ],
          ),
        ),
        '₹449 – ₹499',
      );
    });

    test('an MRP shows the offer', () {
      expect(marketplacePriceLine(_shirt(mrp: 599)), '₹599 → ₹449 · 25% off');
    });
  });
}
