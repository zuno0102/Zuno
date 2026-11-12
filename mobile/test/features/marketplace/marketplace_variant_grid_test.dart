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
  group('MarketplaceVariantGrid', () {
    test('no colours or sizes: one price and stock, sent as the post own', () {
      final grid = MarketplaceVariantGrid(price: 499, stock: 5);
      addTearDown(grid.dispose);

      expect(grid.hasVariants, isFalse);
      expect((grid.price, grid.stock), (499, 5));
      expect(grid.variants, isEmpty);
    });

    test('colours and sizes make every combination, in the order picked', () {
      final grid = MarketplaceVariantGrid();
      addTearDown(grid.dispose);
      grid
        ..toggleColour('Red')
        ..toggleColour('Blue')
        ..toggleSize('M')
        ..toggleSize('L');

      expect(grid.combinations, [
        (colour: 'Red', size: 'M'),
        (colour: 'Red', size: 'L'),
        (colour: 'Blue', size: 'M'),
        (colour: 'Blue', size: 'L'),
      ]);
      expect((grid.price, grid.stock), (null, null));
    });

    test('a colour is picked once, whatever its case, and a second tap '
        'takes it away', () {
      final grid = MarketplaceVariantGrid();
      addTearDown(grid.dispose);
      grid
        ..toggleColour('Red')
        ..toggleColour(' red ');

      expect(grid.colours, isEmpty);
      grid.toggleColour('  ');
      expect(grid.colours, isEmpty, reason: 'a blank is not a colour');
    });

    test('Fill all copies into every row; a left-out one is not sent', () {
      final grid = MarketplaceVariantGrid();
      addTearDown(grid.dispose);
      grid
        ..toggleColour('Red')
        ..toggleColour('Blue')
        ..applyToAll(price: '399', stock: '5')
        ..leaveOut((colour: 'Blue', size: null));

      expect(
        [for (final v in grid.variants) (v.name, v.price, v.stock)],
        [('Red', 399.0, 5)],
      );

      grid
        ..toggleColour('Blue')
        ..toggleColour('Blue');
      expect(
        grid.combinations.length,
        2,
        reason: 'picking it again brings it back',
      );
    });

    test('an edit starts from the saved rows, ids kept, gaps left out', () {
      final grid = MarketplaceVariantGrid(
        price: 449,
        saved: const [
          MarketplaceVariant(id: 'v1', colour: 'Red', size: 'M', stock: 3),
          MarketplaceVariant(
            id: 'v2',
            colour: 'Blue',
            size: 'L',
            stock: 1,
            price: 499,
          ),
        ],
      );
      addTearDown(grid.dispose);

      expect(grid.colours, ['Red', 'Blue']);
      expect(grid.sizes, ['M', 'L']);
      expect(
        [for (final v in grid.variants) (v.id, v.name, v.price, v.stock)],
        [('v1', 'Red · M', 449.0, 3), ('v2', 'Blue · L', 499.0, 1)],
        reason: 'Red · L and Blue · M were never sold',
      );
      expect(grid.highestPrice, 499);
    });
  });

  group('marketplacePriceLine', () {
    test('colours priced apart show the range', () {
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

    test('one price shows once, after the MRP', () {
      expect(marketplacePriceLine(_shirt(mrp: 599)), '₹599 → ₹449');
    });
  });
}
