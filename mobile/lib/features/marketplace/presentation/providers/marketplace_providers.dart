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
///
/// Each lookup is a request, tried twice (a server waking up fails the first). When one still
/// fails and nothing else places the business, it is not known that the address cannot be placed —
/// only that it could not be checked: that is [BusinessPlaceUncheckedException], not null, so the
/// form offers to try again instead of sending a business with an address to add one. Not retried
/// on its own: the lookups were already tried twice, and the form's Retry asks again — while
/// Riverpod's own retries would keep Save waiting with nothing said.
@Riverpod(retry: _noRetry)
Future<District?> marketplaceBusinessDistrict(Ref ref) async {
  final profile = await ref.watch(businessProfileProvider.future);
  var unchecked = false;

  final pin = (profile.latitude, profile.longitude);
  if (pin case (final double latitude, final double longitude)) {
    final fromPin = await _nearestDistrict(ref, latitude, longitude);
    if (fromPin.district case final district?) return district;
    unchecked |= fromPin.failed;
  }

  final address = [
    profile.city,
    profile.postalCode,
    profile.state,
  ].where((p) => p != null && p.trim().isNotEmpty).join(', ');
  if (address.isNotEmpty) {
    final fromAddress = await _districtOfAddress(ref, address);
    if (fromAddress.district case final district?) return district;
    unchecked |= fromAddress.failed;
  }

  String key(String? name) => (name ?? '').trim().toLowerCase();
  final stateName = key(profile.state);
  final town = key(profile.city);
  if (stateName.isNotEmpty && town.isNotEmpty) {
    final districts = await ref.watch(allDistrictsProvider.future);
    final byName = districts
        .where((d) => key(d.stateName) == stateName && key(d.name) == town)
        .firstOrNull;
    if (byName != null) return byName;
  }

  if (unchecked) throw const BusinessPlaceUncheckedException();
  return null;
}

/// The business's place could not be worked out because a lookup failed — offline, or a server
/// not answering — not because its address cannot be placed.
class BusinessPlaceUncheckedException implements Exception {
  const BusinessPlaceUncheckedException();

  @override
  String toString() =>
      "Couldn't check where your business is. Check your connection and try again.";
}

/// Never retried by Riverpod.
Duration? _noRetry(int retryCount, Object error) => null;

/// A lookup's answer: the district (null when there is none), and whether the lookup failed — so
/// "there is none" and "could not ask" stay apart.
typedef _Lookup = ({District? district, bool failed});

/// Runs [lookup], once more if it fails.
Future<T> _twice<T>(Future<T> Function() lookup) async {
  try {
    return await lookup();
  } on Object {
    return lookup();
  }
}

/// The district a point is in; none when it is too far from every one.
Future<_Lookup> _nearestDistrict(
  Ref ref,
  double latitude,
  double longitude,
) async {
  try {
    final district = await _twice(
      () => ref
          .read(customerLocationApiProvider)
          .nearestDistrict(latitude, longitude),
    );
    return (district: district, failed: false);
  } on AppException catch (error, stack) {
    AppLog.handled('marketplace business district (pin)', error, stack);
    return (district: null, failed: true);
  }
}

/// The district a pin dropped on the map is in — a food offer's or advert's own place. Null when the
/// point is outside every district; throws [BusinessPlaceUncheckedException] when it could not be asked.
Future<District?> marketplaceDistrictAt(
  WidgetRef ref,
  double latitude,
  double longitude,
) async {
  try {
    return await _twice(
      () => ref
          .read(customerLocationApiProvider)
          .nearestDistrict(latitude, longitude),
    );
  } on AppException catch (error, stack) {
    AppLog.handled('marketplace post place (pin)', error, stack);
    throw const BusinessPlaceUncheckedException();
  }
}

/// The district a typed address is in, through the map search; none when the map does not know it.
Future<_Lookup> _districtOfAddress(Ref ref, String address) async {
  try {
    final places = await _twice(
      () => ref.read(placeSearchClientProvider).search(address),
    );
    final place = places.firstOrNull;
    return place == null
        ? (district: null, failed: false)
        : await _nearestDistrict(ref, place.latitude, place.longitude);
  } on DioException catch (error, stack) {
    AppLog.handled('marketplace business district (address)', error, stack);
    return (district: null, failed: true);
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
  String? kind,
  bool wholesale = false,
  bool products = false,
  bool inactive = false,
}) {
  final repository = ref.watch(marketplaceRepositoryProvider);
  if (categoryId == null &&
      status == null &&
      kind == null &&
      !wholesale &&
      !products &&
      !inactive) {
    unawaited(repository.syncProfile().then<void>((_) {}, onError: (_) {}));
  }
  return repository.getMyPosts(
    categoryId: categoryId,
    status: status,
    kind: kind,
    wholesale: wholesale,
    products: products,
    inactive: inactive,
  );
}

/// The Stock page: the new products that keep a stock count, each with its colours and sizes — or,
/// with [wholesale], the B2B stock page: the business's B2B posts with their available quantity.
@riverpod
Future<List<MarketplacePost>> marketplaceStock(
  Ref ref, {
  bool wholesale = false,
}) => wholesale
    ? ref.watch(marketplaceRepositoryProvider).getMyPosts(wholesale: true)
    : ref.watch(marketplaceRepositoryProvider).getMyPosts(keepsStock: true);

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
