import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:zuno/core/payments/razorpay_checkout.dart';
import 'package:zuno/features/customer/presentation/providers/customer_home_location_provider.dart';
import 'package:zuno/features/marketplace/data/marketplace_remote_datasource.dart';
import 'package:zuno/features/marketplace/domain/entities/marketplace_customer.dart';
import 'package:zuno/features/marketplace/domain/entities/marketplace_order.dart';
import 'package:zuno/features/marketplace/domain/marketplace_customer_repository.dart';
import 'package:zuno/features/marketplace/presentation/providers/marketplace_providers.dart';

part 'marketplace_customer_providers.g.dart';

@Riverpod(keepAlive: true)
MarketplaceCustomerRepository marketplaceCustomerRepository(Ref ref) =>
    MarketplaceCustomerRepositoryImpl(
      MarketplaceRemoteDataSource(ref.watch(marketplaceDioProvider)),
    );

/// The customer's district — food offers and adverts are local, so the home keeps them to it.
/// Products and B2B lots show everywhere.
@riverpod
Future<MarketplaceHome> marketplaceHome(Ref ref) {
  final district = ref.watch(
    customerHomeLocationProvider.select((l) => l.district?.id),
  );
  return ref
      .watch(marketplaceCustomerRepositoryProvider)
      .getHome(districtIds: district == null ? null : [district]);
}

/// The home's last section so far: the cards loaded, how many there are in all, and whether the
/// next page is on its way.
class MarketplaceFeed {
  const MarketplaceFeed({
    this.items = const [],
    this.hasMore = false,
    this.isLoadingMore = false,
    this.loadFailed = false,
  });

  final List<MarketplaceCard> items;

  /// The server has more after these.
  final bool hasMore;
  final bool isLoadingMore;

  /// The last page did not come; the customer asks again rather than the app retrying by itself.
  final bool loadFailed;
}

/// "All products" at the foot of the home — products and B2B lots from everywhere, food in the
/// customer's district — a page of [pageSize] at a time as they scroll.
@riverpod
class MarketplaceFeedNotifier extends _$MarketplaceFeedNotifier {
  int _page = 1;
  String? _district;

  @override
  Future<MarketplaceFeed> build(int pageSize) async {
    _district = ref.watch(
      customerHomeLocationProvider.select((l) => l.district?.id),
    );
    _page = 1;
    final page = await _fetch(1);
    return MarketplaceFeed(items: page.items, hasMore: _more(page, 1));
  }

  /// The next page, unless one is loading or there are no more. A failure keeps what is shown
  /// and waits for the customer to ask again.
  Future<void> loadMore() async {
    final current = state.value;
    if (current == null || !current.hasMore || current.isLoadingMore) return;

    state = AsyncData(
      MarketplaceFeed(items: current.items, hasMore: true, isLoadingMore: true),
    );
    try {
      final page = await _fetch(_page + 1);
      _page++;
      // A post can move up a page while the customer scrolls; show it once.
      final seen = {for (final c in current.items) c.id};
      state = AsyncData(
        MarketplaceFeed(
          items: [...current.items, ...page.items.where((c) => seen.add(c.id))],
          hasMore: _more(page, _page),
        ),
      );
    } catch (_) {
      state = AsyncData(
        MarketplaceFeed(items: current.items, hasMore: true, loadFailed: true),
      );
    }
  }

  /// More after page [number]: a full page, and the count says so. A short page is the last.
  bool _more(MarketplaceCardPage page, int number) =>
      page.items.length >= pageSize && number * pageSize < page.totalCount;

  Future<MarketplaceCardPage> _fetch(int page) {
    final district = _district;
    return ref
        .read(marketplaceCustomerRepositoryProvider)
        .search(
          feed: true,
          districtIds: district == null ? null : [district],
          page: page,
          pageSize: pageSize,
        );
  }
}

/// What the customer searched for on the Marketplace home.
typedef MarketplaceSearchQuery = ({String? keyword, String? categoryId});

/// The first page of matching posts — products, food, adverts and B2B lots alike.
@riverpod
Future<MarketplaceCardPage> marketplaceSearch(
  Ref ref,
  MarketplaceSearchQuery query,
) => ref
    .watch(marketplaceCustomerRepositoryProvider)
    .search(keyword: query.keyword, categoryId: query.categoryId);

/// A post as the customer opens it.
@riverpod
Future<MarketplacePostDetail> marketplacePost(Ref ref, String id) =>
    ref.watch(marketplaceCustomerRepositoryProvider).getPost(id);

@riverpod
Future<MarketplaceCardPage> marketplaceFavourites(Ref ref) =>
    ref.watch(marketplaceCustomerRepositoryProvider).getFavourites();

/// The hearts the customer tapped this session, ahead of the server: a tap shows at once, and goes
/// back if the server refuses it. Cards read [isSaved] with the server's own answer as the fallback.
@Riverpod(keepAlive: true)
class MarketplaceSavedPosts extends _$MarketplaceSavedPosts {
  @override
  Map<String, bool> build() => const {};

  bool isSaved(MarketplaceCard card) => state[card.id] ?? card.isFavourite;

  /// Flips the heart. Throws (after putting it back) when the server refuses.
  Future<void> toggle(MarketplaceCard card) async {
    final saved = !isSaved(card);
    state = {...state, card.id: saved};
    try {
      await ref
          .read(marketplaceCustomerRepositoryProvider)
          .setFavourite(card.id, saved: saved);
      ref.invalidate(marketplaceFavouritesProvider);
    } catch (_) {
      state = {...state, card.id: !saved};
      rethrow;
    }
  }
}

/// The customer's product orders narrowed to [status], with a chip per status they have.
@riverpod
Future<MarketplaceOrderPage> myMarketplaceOrders(Ref ref, {String? status}) =>
    ref
        .watch(marketplaceCustomerRepositoryProvider)
        .getMyOrders(status: status);

/// One of the customer's orders, with its progress bar and history.
@riverpod
Future<MarketplaceOrder> myMarketplaceOrder(Ref ref, String id) =>
    ref.watch(marketplaceCustomerRepositoryProvider).getMyOrder(id);

/// The B2B lots the customer asked for.
@riverpod
Future<MarketplaceB2BRequestPage> myMarketplaceRequests(Ref ref) =>
    ref.watch(marketplaceCustomerRepositoryProvider).getMyRequests();

/// Opens the payment window for a checkout and resolves with what it returns, or throws
/// [RazorpayCancelled]. A provider, so tests answer it without a payment SDK.
typedef MarketplacePaymentWindow =
    Future<RazorpayResult> Function(MarketplaceCheckout checkout, String payee);

@Riverpod(keepAlive: true)
MarketplacePaymentWindow marketplacePaymentWindow(Ref ref) =>
    (checkout, payee) => RazorpayCheckout.open(
      keyId: checkout.keyId,
      orderId: checkout.providerOrderId,
      amount: checkout.amount,
      description: checkout.description,
      businessName: payee,
    );
