/// A narrower kind of work inside a category, as the app owner sees it.
///
/// Hidden rows are included here and nowhere else. This screen is the only place a hidden
/// sub-category can be brought back, so it is the only place that may show one.
class CatalogSubCategory {
  const CatalogSubCategory({
    required this.id,
    required this.serviceCategoryId,
    required this.name,
    required this.slug,
    required this.displayOrder,
    required this.isActive,
  });

  final String id;
  final String serviceCategoryId;
  final String name;
  final String slug;
  final int displayOrder;

  /// False means hidden from the pickers. Nothing in the catalogue is ever deleted.
  final bool isActive;
}

/// A main kind of work, as the app owner sees it.
class CatalogCategory {
  const CatalogCategory({
    required this.id,
    required this.name,
    required this.slug,
    required this.displayOrder,
    required this.isActive,
    required this.serviceCount,
    this.description,
    this.iconUrl,
    this.subCategories = const [],
  });

  final String id;
  final String name;
  final String slug;
  final String? description;
  final String? iconUrl;
  final int displayOrder;
  final bool isActive;

  /// How many services businesses have already listed under this category.
  ///
  /// Shown beside the Hide control so the decision is made with the consequence in view:
  /// hiding a category with 14 services behind it is a different act from hiding an empty one.
  final int serviceCount;

  final List<CatalogSubCategory> subCategories;

  bool get isInUse => serviceCount > 0;

  int get visibleSubCategoryCount => subCategories.where((s) => s.isActive).length;
}
