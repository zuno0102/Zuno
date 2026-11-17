import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zuno/features/business_owner/presentation/widgets/service_media_slots.dart';
import 'package:zuno/features/marketplace/domain/entities/marketplace_post.dart';
import 'package:zuno/features/marketplace/domain/marketplace_repository.dart';
import 'package:zuno/features/marketplace/presentation/widgets/marketplace_product_sections.dart';

/// Only the photo calls: everything else is not used here.
class _PhotoRepository implements MarketplaceRepository {
  _PhotoRepository(this.saved);

  final MarketplacePost saved;
  final uploads = <(String?, int)>[];
  final removals = <(String?, int)>[];

  @override
  Future<MarketplacePost> uploadImage(
    String id,
    int slot,
    Uint8List bytes, {
    String? variantId,
  }) async {
    uploads.add((variantId, slot));
    return saved;
  }

  @override
  Future<MarketplacePost> removeImage(
    String id,
    int slot, {
    String? variantId,
  }) async {
    removals.add((variantId, slot));
    return saved;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

MarketplacePost _saree(List<MarketplaceVariant> variants) => MarketplacePost(
  id: 'p-1',
  categoryId: 'cat-products',
  categoryName: 'Products',
  kind: MarketplacePostKind.listing,
  status: MarketplacePostStatus.active,
  title: 'Silk saree',
  tradeType: MarketplaceTradeType.retail,
  districtId: 'd-kk',
  districtName: 'Kanyakumari',
  stateId: 's-tn',
  stateName: 'Tamil Nadu',
  attributes: const {},
  imageUrls: const {},
  actions: const [],
  condition: MarketplaceItemCondition.newItem,
  variants: variants,
);

final _bytes = Uint8List.fromList([1, 2, 3]);

void main() {
  group('sending a colour / size\'s photos after the save', () {
    test(
      'a new colour is found by its colour and size, an old one by its id',
      () async {
        final list = MarketplaceVariantList(const [
          MarketplaceVariant(
            id: 'v-green',
            colour: 'Green',
            stock: 3,
            imageUrls: {0: '/g0.jpg'},
          ),
        ]);
        final greenPhotos =
            ServiceMediaSelection(
                slotCount: 3,
                savedImageUrl: (slot) => slot == 0 ? '/g0.jpg' : null,
              )
              ..removeImage(0)
              ..setImage(1, _bytes);
        list.put(list.items.single, at: 0, photos: greenPhotos);
        final bluePhotos = ServiceMediaSelection(slotCount: 3)
          ..setImage(0, _bytes);
        list.put(
          const MarketplaceVariant(colour: ' blue ', stock: 2),
          photos: bluePhotos,
        );
        // Untouched photos are not sent.
        list.put(
          const MarketplaceVariant(colour: 'Yellow', stock: 1),
          photos: ServiceMediaSelection(slotCount: 3),
        );

        final repo = _PhotoRepository(
          _saree(const [
            MarketplaceVariant(id: 'v-red', colour: 'Red', stock: 10),
            MarketplaceVariant(id: 'v-green', colour: 'Green', stock: 3),
            MarketplaceVariant(id: 'v-blue', colour: 'Blue', stock: 2),
            MarketplaceVariant(id: 'v-yellow', colour: 'Yellow', stock: 1),
          ]),
        );

        await uploadMarketplaceVariantPhotos(
          repo,
          repo.saved,
          list.pendingPhotos,
        );

        expect(repo.uploads, [('v-green', 1), ('v-blue', 0)]);
        expect(repo.removals, [('v-green', 0)]);
        list.dispose();
      },
    );

    test('nothing picked: nothing sent', () async {
      final list = MarketplaceVariantList(const [
        MarketplaceVariant(id: 'v-green', colour: 'Green', stock: 3),
      ]);
      final repo = _PhotoRepository(_saree(list.items));

      await uploadMarketplaceVariantPhotos(
        repo,
        repo.saved,
        list.pendingPhotos,
      );

      expect(repo.uploads, isEmpty);
      expect(repo.removals, isEmpty);
      list.dispose();
    });

    test(
      'a colour taken off frees its photos, and the list frees the rest',
      () {
        final photos = ServiceMediaSelection(slotCount: 3)..setImage(0, _bytes);
        final list = MarketplaceVariantList(const [])
          ..put(
            const MarketplaceVariant(colour: 'Blue', stock: 2),
            photos: photos,
          );

        list.removeAt(0);

        expect(list.pendingPhotos, isEmpty);
        expect(
          () => photos.addListener(() {}),
          throwsFlutterError,
          reason: 'disposed',
        );
        list.dispose();
      },
    );
  });

  testWidgets('the colour / size sheet has its own photo slots', (
    tester,
  ) async {
    MarketplaceVariantEdit? result;
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () async =>
                    result = await showMarketplaceVariantSheet(
                      context,
                      existing: const MarketplaceVariant(
                        id: 'v-green',
                        colour: 'Green',
                        price: 449,
                        stock: 3,
                      ),
                      startPrice: 449,
                      others: const [],
                      limits: const MarketplaceTextLimits(),
                      maxQuantity: 1000,
                      photoSlots: 2,
                    ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('marketplace-variant-photos')),
      findsOneWidget,
    );
    expect(
      find.text(
        'Photos of this colour / size. Sent when you save the product.',
      ),
      findsOneWidget,
    );
    final save = find.byKey(const ValueKey('marketplace-variant-save'));
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pumpAndSettle();

    final (variant, photos) = result!;
    expect(variant.colour, 'Green');
    expect(photos.slotCount, 2);
    expect(photos.hasChanges, isFalse);
  });
}
