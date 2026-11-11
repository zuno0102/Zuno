import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' show WidgetRef;
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:zuno/core/network/dio_client.dart';
import 'package:zuno/features/auth/presentation/providers/auth_providers.dart';
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

/// The categories a business can post in, with their details. The server caches them too.
@riverpod
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

/// The business's posts; [kind] and [status] narrow the list (null for all).
///
/// Loading the full list also refreshes how customers see the business (name, verified) — in the
/// background, so a slow or failed refresh never holds up the business's own list.
@riverpod
Future<List<MarketplacePost>> businessMarketplacePosts(
  Ref ref, {
  String? kind,
  String? status,
}) {
  final repository = ref.watch(marketplaceRepositoryProvider);
  if (kind == null && status == null) {
    unawaited(repository.syncProfile().then<void>((_) {}, onError: (_) {}));
  }
  return repository.getMyPosts(kind: kind, status: status);
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
