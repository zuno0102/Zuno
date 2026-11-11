import 'dart:typed_data';

import 'package:zuno/features/marketplace/domain/entities/marketplace_post.dart';

/// The Marketplace service — its own server and database, signed in with the shared login.
abstract interface class MarketplaceRepository {
  /// The active categories, each with the details it asks for.
  Future<List<MarketplaceCategory>> getCategories();

  Future<MarketplaceOptions> getOptions();

  Future<MarketplaceSummary> getSummary();

  /// The business's posts, newest first; [kind] and [status] narrow the list.
  Future<List<MarketplacePost>> getMyPosts({String? kind, String? status});

  Future<MarketplacePost> create(MarketplacePostInput input);

  Future<MarketplacePost> update(String id, MarketplacePostInput input);

  Future<MarketplacePost> changeStatus(String id, String status);

  Future<void> delete(String id);

  Future<MarketplacePost> uploadImage(String id, int slot, Uint8List bytes);

  Future<MarketplacePost> removeImage(String id, int slot);

  /// Refreshes the business's name and verification from its Service profile.
  Future<MarketplaceBusiness> syncProfile();

  /// The super admin's view: every category, switched off or not.
  Future<List<MarketplaceCategory>> getAllCategories();

  Future<MarketplaceCategory> createCategory(MarketplaceCategoryInput input);

  Future<MarketplaceCategory> updateCategory(
    String id,
    MarketplaceCategoryInput input,
  );

  Future<MarketplaceCategory> createField(
    String categoryId,
    MarketplaceFieldInput input,
  );

  Future<MarketplaceCategory> updateField(
    String categoryId,
    String fieldId,
    MarketplaceFieldInput input,
  );
}
