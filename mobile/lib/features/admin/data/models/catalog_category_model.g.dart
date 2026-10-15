// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'catalog_category_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CatalogSubCategoryModel _$CatalogSubCategoryModelFromJson(
  Map<String, dynamic> json,
) => CatalogSubCategoryModel(
  id: json['id'] as String,
  serviceCategoryId: json['serviceCategoryId'] as String,
  name: json['name'] as String,
  slug: json['slug'] as String,
  displayOrder: (json['displayOrder'] as num).toInt(),
  isActive: json['isActive'] as bool,
);

CatalogCategoryModel _$CatalogCategoryModelFromJson(
  Map<String, dynamic> json,
) => CatalogCategoryModel(
  id: json['id'] as String,
  name: json['name'] as String,
  slug: json['slug'] as String,
  displayOrder: (json['displayOrder'] as num).toInt(),
  isActive: json['isActive'] as bool,
  serviceCount: (json['serviceCount'] as num).toInt(),
  description: json['description'] as String?,
  iconUrl: json['iconUrl'] as String?,
  subCategories:
      (json['subCategories'] as List<dynamic>?)
          ?.map(
            (e) => CatalogSubCategoryModel.fromJson(e as Map<String, dynamic>),
          )
          .toList() ??
      const [],
);
