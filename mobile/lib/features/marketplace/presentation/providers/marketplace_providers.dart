import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' show WidgetRef;
import 'package:riverpod_annotation/riverpod_annotation.dart';
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

/// Where the business is, as a district — where its products are said to be, so the form does not
/// ask. From its registered pin; else its town and state matched by name; null when neither does,
/// and the form then asks for the district.
@riverpod
Future<District?> marketplaceBusinessDistrict(Ref ref) async {
  final profile = await ref.watch(businessProfileProvider.future);
  final latitude = profile.latitude;
  final longitude = profile.longitude;
  if (latitude != null && longitude != null) {
    try {
      final nearest = await ref
          .read(customerLocationApiProvider)
          .nearestDistrict(latitude, longitude);
      if (nearest != null) return nearest;
    } catch (_) {
      // Offline or refused: the names below may still say where it is.
    }
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
}) {
  final repository = ref.watch(marketplaceRepositoryProvider);
  if (categoryId == null && status == null) {
    unawaited(repository.syncProfile().then<void>((_) {}, onError: (_) {}));
  }
  return repository.getMyPosts(categoryId: categoryId, status: status);
}

/// The super admin's categories: every one, switched off or not.
@riverpod
Future<List<MarketplaceCategory>> adminMarketplaceCategories(Ref ref) =>
    ref.watch(marketplaceRepositoryProvider).getAllCategories();

/// After any change to a post: reloads the Marketplace tab, the home tiles and the plan banner.
void reloadMarketplace(WidgetRef ref) {
  ref
    ..invalidate(businessMarketplacePostsProvider)
    ..invalidate(marketplaceSummaryProvider);
}

/// After the super admin changes a category: reloads both the admin list and the post form's.
void reloadMarketplaceCategories(WidgetRef ref) {
  ref
    ..invalidate(adminMarketplaceCategoriesProvider)
    ..invalidate(marketplaceCategoriesProvider);
}
