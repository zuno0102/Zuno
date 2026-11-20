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
