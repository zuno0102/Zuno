import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' show WidgetRef;
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:zuno/core/error/app_exceptions.dart';
import 'package:zuno/core/logging/app_log.dart';
import 'package:zuno/core/network/dio_client.dart';
import 'package:zuno/features/auth/presentation/providers/auth_providers.dart';
import 'package:zuno/features/business_owner/presentation/providers/business_profile_notifier.dart';
import 'package:zuno/features/catalog/domain/entities/district.dart';
import 'package:zuno/features/catalog/presentation/providers/catalog_providers.dart';
import 'package:zuno/features/customer/data/datasources/customer_location_api.dart';
import 'package:zuno/features/marketplace/data/marketplace_api.dart';
import 'package:zuno/features/marketplace/data/marketplace_remote_datasource.dart';
import 'package:zuno/features/marketplace/data/marketplace_repository_impl.dart';
import 'package:zuno/features/marketplace/domain/entities/marketplace_post.dart';
import 'package:zuno/features/marketplace/domain/marketplace_repository.dart';
import 'package:zuno/features/worker/presentation/widgets/place_search_sheet.dart';

part 'marketplace_providers.g.dart';

/// The app's usual client, pointed at the Marketplace service. Same interceptors, and the very
/// same [authInterceptorProvider], so Marketplace shares the login and its one token refresh.
@Riverpod(keepAlive: true)
Dio marketplaceDio(Ref ref) =>
    buildDioClient(authInterceptor: ref.watch(authInterceptorProvider))
      ..options.baseUrl = MarketplaceApi.baseUrl;

@Riverpod(keepAlive: true)
MarketplaceRepository marketplaceRepository(Ref ref) =>
    MarketplaceRepositoryImpl(
      MarketplaceRemoteDataSource(ref.watch(marketplaceDioProvider)),
    );

/// Where the business is, as a district — where its posts are said to be, so the post form never
/// asks. Tried in turn, each only if the one before says nothing:
/// 1. its registered map pin;
/// 2. its registered address (street, town, PIN code, state) found on the map;
/// 3. its town matched to a district's name in its state.
/// Null when none does: the form then sends the business to its profile.
@riverpod
Future<District?> marketplaceBusinessDistrict(Ref ref) async {
  final profile = await ref.watch(businessProfileProvider.future);
  final pin = (profile.latitude, profile.longitude);
  if (pin case (final double latitude, final double longitude)) {
    final fromPin = await _nearestDistrict(ref, latitude, longitude);
    if (fromPin != null) return fromPin;
  }

  final address = [
    profile.city,
    profile.postalCode,
    profile.state,
  ].where((p) => p != null && p.trim().isNotEmpty).join(', ');
  if (address.isNotEmpty) {
    final fromAddress = await _districtOfAddress(ref, address);
    if (fromAddress != null) return fromAddress;
  }

  String key(String? name) => (name ?? '').trim().toLowerCase();
  final stateName = key(profile.state);
  final town = key(profile.city);
  if (stateName.isEmpty || town.isEmpty) return null;
  final districts = await ref.watch(allDistrictsProvider.future);
  return districts
      .where((d) => key(d.stateName) == stateName && key(d.name) == town)
      .firstOrNull;
}

/// The district a point is in; null when it cannot be told — offline, or too far from every one.
Future<District?> _nearestDistrict(
  Ref ref,
  double latitude,
  double longitude,
) async {
  try {
    return await ref
        .read(customerLocationApiProvider)
        .nearestDistrict(latitude, longitude);
  } on AppException catch (error, stack) {
    AppLog.handled('marketplace business district (pin)', error, stack);
    return null;
  }
}

/// The district a typed address is in, through the map search; null when the map does not know it.
Future<District?> _districtOfAddress(Ref ref, String address) async {
  try {
    final places = await ref.read(placeSearchClientProvider).search(address);
    final place = places.firstOrNull;
    return place == null
        ? null
        : await _nearestDistrict(ref, place.latitude, place.longitude);
  } on DioException catch (error, stack) {
    AppLog.handled('marketplace business district (address)', error, stack);
    return null;
  }
}

/// The categories a business can post in, with their details. The server caches them too. Kept
/// for the session — they change only when the super admin edits them, which reloads them — so
/// opening a Marketplace screen again costs no request.
@Riverpod(keepAlive: true)
Future<List<MarketplaceCategory>> marketplaceCategories(Ref ref) =>
    ref.watch(marketplaceRepositoryProvider).getCategories();

/// The post kinds, statuses (with colours) and limits, from the server's tables.
@Riverpod(keepAlive: true)
Future<MarketplaceOptions> marketplaceOptions(Ref ref) =>
    ref.watch(marketplaceRepositoryProvider).getOptions();

/// The counts behind the Marketplace tiles, and the plan banner.
@riverpod
Future<MarketplaceSummary> marketplaceSummary(Ref ref) =>
    ref.watch(marketplaceRepositoryProvider).getSummary();

/// The business's posts; [categoryId] (a main category) and [status] narrow the list (null for all).
///
/// Loading the full list also refreshes how customers see the business (name, verified) — in the
/// background, so a slow or failed refresh never holds up the business's own list.
@riverpod
Future<List<MarketplacePost>> businessMarketplacePosts(
  Ref ref, {
  String? categoryId,
  String? status,
  bool inactive = false,
}) {
  final repository = ref.watch(marketplaceRepositoryProvider);
  if (categoryId == null && status == null && !inactive) {
    unawaited(repository.syncProfile().then<void>((_) {}, onError: (_) {}));
  }
  return repository.getMyPosts(
    categoryId: categoryId,
    status: status,
    inactive: inactive,
  );
}

/// The Stock page: the new products that keep a stock count, each with its colours and sizes.
@riverpod
Future<List<MarketplacePost>> marketplaceStock(Ref ref) =>
    ref.watch(marketplaceRepositoryProvider).getMyPosts(keepsStock: true);

/// The super admin's categories: every one, switched off or not.
@riverpod
Future<List<MarketplaceCategory>> adminMarketplaceCategories(Ref ref) =>
    ref.watch(marketplaceRepositoryProvider).getAllCategories();

/// After any change to a post: reloads the Marketplace tab, the Stock page, the home tiles and the
/// plan banner.
void reloadMarketplace(WidgetRef ref) {
  ref
    ..invalidate(businessMarketplacePostsProvider)
    ..invalidate(marketplaceStockProvider)
    ..invalidate(marketplaceSummaryProvider);
}

/// After the super admin changes a category: reloads both the admin list and the post form's.
void reloadMarketplaceCategories(WidgetRef ref) {
  ref
    ..invalidate(adminMarketplaceCategoriesProvider)
    ..invalidate(marketplaceCategoriesProvider);
}
