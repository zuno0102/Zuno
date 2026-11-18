import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:zuno/features/marketplace/data/marketplace_remote_datasource.dart';
import 'package:zuno/features/marketplace/domain/entities/marketplace_order.dart';
import 'package:zuno/features/marketplace/domain/marketplace_order_repository.dart';
import 'package:zuno/features/marketplace/presentation/providers/marketplace_providers.dart';

part 'marketplace_order_providers.g.dart';

@Riverpod(keepAlive: true)
MarketplaceOrderRepository marketplaceOrderRepository(Ref ref) =>
    MarketplaceOrderRepositoryImpl(
      MarketplaceRemoteDataSource(ref.watch(marketplaceDioProvider)),
    );

/// The business's product orders narrowed to [status] (null for all), with every status's count.
@riverpod
Future<MarketplaceOrderPage> businessMarketplaceOrders(
  Ref ref, {
  String? status,
}) => ref.watch(marketplaceOrderRepositoryProvider).getOrders(status: status);

/// One order with its history, for its own page.
@riverpod
Future<MarketplaceOrder> businessMarketplaceOrder(Ref ref, String id) =>
    ref.watch(marketplaceOrderRepositoryProvider).getOrder(id);

/// The B2B requests on the business's lots narrowed to [status], with every status's count.
@riverpod
Future<MarketplaceB2BRequestPage> businessB2BRequests(
  Ref ref, {
  String? status,
}) => ref
    .watch(marketplaceOrderRepositoryProvider)
    .getB2BRequests(status: status);

@riverpod
Future<MarketplacePaymentSettings> marketplacePaymentSettings(Ref ref) =>
    ref.watch(marketplaceOrderRepositoryProvider).getPaymentSettings();
