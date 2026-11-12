import 'dart:typed_data';

import 'package:zuno/features/marketplace/data/marketplace_remote_datasource.dart';
import 'package:zuno/features/marketplace/domain/entities/marketplace_post.dart';
import 'package:zuno/features/marketplace/domain/marketplace_repository.dart';

class MarketplaceRepositoryImpl implements MarketplaceRepository {
  MarketplaceRepositoryImpl(this._remote);

  final MarketplaceRemoteDataSource _remote;

  /// The page asked for when listing a business's posts — the server caps it too.
  static const listPageSize = 100;

  @override
  Future<List<MarketplaceCategory>> getCategories() async => [
    for (final c in await _remote.getCategories()) c.toEntity(),
  ];

  @override
  Future<List<MarketplaceCategory>> getAllCategories() async => [
    for (final c in await _remote.getCategories(all: true)) c.toEntity(),
  ];

  @override
  Future<MarketplaceOptions> getOptions() async =>
      (await _remote.getOptions()).toEntity();

  @override
  Future<MarketplaceSummary> getSummary() async =>
      (await _remote.getSummary()).toEntity();

  @override
  Future<List<MarketplacePost>> getMyPosts({
    String? categoryId,
    String? status,
    bool keepsStock = false,
    bool inactive = false,
  }) async => [
    for (final p in (await _remote.getMyPosts(
      categoryId: categoryId,
      status: status,
      keepsStock: keepsStock,
      inactive: inactive,
      pageSize: listPageSize,
    )).items)
      p.toEntity(),
  ];

  @override
  Future<MarketplacePost> create(MarketplacePostInput input) async =>
      (await _remote.create(input.toJson())).toEntity();

  @override
  Future<MarketplacePost> update(String id, MarketplacePostInput input) async =>
      (await _remote.update(id, input.toJson())).toEntity();

  @override
  Future<MarketplacePost> changeStatus(String id, String status) async =>
      (await _remote.changeStatus(id, status)).toEntity();

  @override
  Future<MarketplacePost> updateStock(
    String id,
    int quantity, {
    String? variantId,
  }) async => (await _remote.updateStock(
    id,
    quantity,
    variantId: variantId,
  )).toEntity();

  @override
  Future<MarketplacePost> replaceVariants(
    String id,
    List<MarketplaceVariant> variants,
  ) async => (await _remote.replaceVariants(id, [
    for (final v in variants) v.toJson(),
  ])).toEntity();

  @override
  Future<void> delete(String id) => _remote.delete(id);

  @override
  Future<MarketplacePost> uploadImage(
    String id,
    int slot,
    Uint8List bytes,
  ) async => (await _remote.uploadImage(id, slot, bytes)).toEntity();

  @override
  Future<MarketplacePost> removeImage(String id, int slot) async =>
      (await _remote.removeImage(id, slot)).toEntity();

  @override
  Future<MarketplaceBusiness> syncProfile() async =>
      (await _remote.syncProfile()).toEntity();

  @override
  Future<MarketplaceCategory> createCategory(
    MarketplaceCategoryInput input,
  ) async => (await _remote.saveCategory(input.toJson())).toEntity();

  @override
  Future<MarketplaceCategory> updateCategory(
    String id,
    MarketplaceCategoryInput input,
  ) async => (await _remote.saveCategory(input.toJson(), id: id)).toEntity();

  @override
  Future<MarketplaceCategory> createSubCategory(
    String categoryId,
    MarketplaceSubCategoryInput input,
  ) async =>
      (await _remote.saveSubCategory(categoryId, input.toJson())).toEntity();

  @override
  Future<MarketplaceCategory> updateSubCategory(
    String categoryId,
    String subId,
    MarketplaceSubCategoryInput input,
  ) async => (await _remote.saveSubCategory(
    categoryId,
    input.toJson(),
    subId: subId,
  )).toEntity();

  @override
  Future<MarketplaceCategory> createField(
    String categoryId,
    MarketplaceFieldInput input,
  ) async => (await _remote.saveField(categoryId, input.toJson())).toEntity();

  @override
  Future<MarketplaceCategory> updateField(
    String categoryId,
    String fieldId,
    MarketplaceFieldInput input,
  ) async => (await _remote.saveField(
    categoryId,
    input.toJson(),
    fieldId: fieldId,
  )).toEntity();
}
