import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart'
    show ProviderScope, WidgetRef;
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:zuno/core/network/dio_client.dart';
import 'package:zuno/features/auth/presentation/providers/auth_providers.dart';
import 'package:zuno/features/rental/data/rental_api.dart';
import 'package:zuno/features/rental/data/rental_remote_datasource.dart';
import 'package:zuno/features/rental/domain/entities/rental_item.dart';
import 'package:zuno/features/rental/domain/entities/rental_stock.dart';
import 'package:zuno/features/rental/data/rental_repository_impl.dart';
import 'package:zuno/features/rental/domain/rental_repository.dart';
import 'package:zuno/features/rental/presentation/providers/rental_order_providers.dart';

part 'rental_providers.g.dart';

/// The app's usual client, pointed at the Rent service. Same interceptors, and the very same
/// [authInterceptorProvider], so Rent shares the login and its one token refresh.
@Riverpod(keepAlive: true)
Dio rentDio(Ref ref) =>
    buildDioClient(authInterceptor: ref.watch(authInterceptorProvider))
      ..options.baseUrl = RentApi.baseUrl;

@Riverpod(keepAlive: true)
RentalRepository rentalRepository(Ref ref) =>
    RentalRepositoryImpl(RentalRemoteDataSource(ref.watch(rentDioProvider)));

/// The rent catalogue — categories with their sub-categories. Read once per session; the server
/// caches it as well.
@Riverpod(keepAlive: true)
Future<List<RentalCategory>> rentalCategories(Ref ref) =>
    ref.watch(rentalRepositoryProvider).getCategories();

/// How a rent item can be charged — names, explanations and suffixes from the server's table.
@Riverpod(keepAlive: true)
Future<List<RentalPriceTypeOption>> rentalPriceTypes(Ref ref) =>
    ref.watch(rentalRepositoryProvider).getPriceTypes();

/// The counts behind the business home screen's Rent tiles.
@riverpod
Future<RentalSummary> rentalSummary(Ref ref) =>
    ref.watch(rentalRepositoryProvider).getSummary();

/// Only the items available now (true) or switched off (false) — what a Rent tile opens.
@riverpod
Future<List<RentalItem>> rentalItemsByAvailability(Ref ref, bool isAvailable) =>
    ref.watch(rentalRepositoryProvider).getMyItems(isAvailable: isAvailable);

/// The Stock page: each item with in, out and total.
@riverpod
Future<List<RentalStockLine>> rentalStock(Ref ref) =>
    ref.watch(rentalRepositoryProvider).getStock();

/// One item's orders — where its pieces went.
@riverpod
Future<List<RentalOrder>> rentalItemOrders(Ref ref, String rentalItemId) =>
    ref.watch(rentalRepositoryProvider).getItemOrders(rentalItemId);

/// The signed-in business's rent items, newest first.
///
/// Loading it also refreshes how customers see the business (name, logo, verified) — in the
/// background, so a slow or failed refresh never holds up the business's own list.
@riverpod
Future<List<RentalItem>> businessRentals(Ref ref) {
  final repository = ref.watch(rentalRepositoryProvider);
  unawaited(repository.syncProfile().catchError((_) {}));
  return repository.getMyItems();
}

/// After any change to an item: reloads the Rent tab, the home screen's Rent tiles and the
/// filtered lists they open, wherever the change was made from.
///
/// Invalidation rather than a notifier method: a list opened from a tile does not watch the full
/// list, so a reload routed through that list's notifier would reach nothing on screen.
void reloadRentals(WidgetRef ref) => _reloadAll(ref.invalidate);

/// [reloadRentals] for after an await: taken while the widget is still on screen, it still works
/// once the widget has gone — a payment window the customer leaves open while the sheet behind it
/// closes, or a screen they back out of mid-request. A widget's ref is unusable by then, and using
/// it showed "Bad state: Using ref…" over a payment that had in fact been saved.
void Function() rentalReloader(WidgetRef ref) {
  final container = ProviderScope.containerOf(ref.context, listen: false);
  return () => _reloadAll(container.invalidate);
}

void _reloadAll(void Function(ProviderOrFamily provider) invalidate) {
  invalidate(businessRentalsProvider);
  invalidate(rentalSummaryProvider);
  invalidate(rentalItemsByAvailabilityProvider);
  invalidate(rentalStockProvider);
  invalidate(rentalItemOrdersProvider);
  invalidate(rentalOrdersProvider);
  invalidate(rentalOrderCountsProvider);
  invalidate(rentalOrderProvider);
  invalidate(rentalOrderHistoryProvider);
}
