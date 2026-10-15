// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'service_category_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ServiceCategoryModel _$ServiceCategoryModelFromJson(
  Map<String, dynamic> json,
) => ServiceCategoryModel(
  id: json['id'] as String,
  name: json['name'] as String,
  slug: json['slug'] as String,
  description: json['description'] as String?,
  iconUrl: json['iconUrl'] as String?,
  iconName: json['iconName'] as String?,
  subCategories:
      (json['subCategories'] as List<dynamic>?)
          ?.map(
            (e) => ServiceSubCategoryModel.fromJson(e as Map<String, dynamic>),
          )
          .toList() ??
      const [],
);
