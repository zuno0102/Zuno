import 'package:json_annotation/json_annotation.dart';
import 'package:zuno/features/admin/domain/entities/catalog_category.dart';

part 'catalog_category_model.g.dart';

@JsonSerializable(createToJson: false)
class CatalogSubCategoryModel {
  const CatalogSubCategoryModel({
    required this.id,
    required this.serviceCategoryId,
    required this.name,
    required this.slug,
    required this.displayOrder,
    required this.isActive,
  });

  factory CatalogSubCategoryModel.fromJson(Map<String, dynamic> json) =>
      _$CatalogSubCategoryModelFromJson(json);

  final String id;
  final String serviceCategoryId;
  final String name;
  final String slug;
  final int displayOrder;
  final bool isActive;

  CatalogSubCategory toEntity() => CatalogSubCategory(
    id: id,
    serviceCategoryId: serviceCategoryId,
    name: name,
    slug: slug,
    displayOrder: displayOrder,
    isActive: isActive,
  );
}

@JsonSerializable(createToJson: false)
class CatalogCategoryModel {
  const CatalogCategoryModel({
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

  factory CatalogCategoryModel.fromJson(Map<String, dynamic> json) =>
      _$CatalogCategoryModelFromJson(json);

  final String id;
  final String name;
  final String slug;
  final String? description;
  final String? iconUrl;
  final int displayOrder;
  final bool isActive;
  final int serviceCount;
  final List<CatalogSubCategoryModel> subCategories;

  CatalogCategory toEntity() => CatalogCategory(
    id: id,
    name: name,
    slug: slug,
    description: description,
    iconUrl: iconUrl,
    displayOrder: displayOrder,
    isActive: isActive,
    serviceCount: serviceCount,
    subCategories: subCategories.map((s) => s.toEntity()).toList(),
  );
}
