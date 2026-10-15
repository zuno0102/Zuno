import 'package:zuno/features/admin/domain/entities/catalog_category.dart';

abstract interface class AdminCatalogRepository {
  /// Every category and sub-category, hidden ones included.
  Future<List<CatalogCategory>> getCatalog();

  /// Adds a category when [id] is null, otherwise edits that one.
  Future<CatalogCategory> saveCategory({
    String? id,
    required String name,
    String? description,
    required int displayOrder,
    required bool isActive,
  });

  /// Adds a sub-category when [id] is null, otherwise edits that one.
  ///
  /// [categoryId] cannot change on an edit — the server refuses a move, because items already
  /// priced under it belong to services in the original category.
  Future<CatalogSubCategory> saveSubCategory({
    String? id,
    required String categoryId,
    required String name,
    required int displayOrder,
    required bool isActive,
  });
}
