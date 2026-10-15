import 'package:json_annotation/json_annotation.dart';
import 'package:zuno/features/catalog/data/models/service_sub_category_model.dart';
import 'package:zuno/features/catalog/domain/entities/service_category.dart';

part 'service_category_model.g.dart';

@JsonSerializable(createToJson: false)
class ServiceCategoryModel {
  const ServiceCategoryModel({
    required this.id,
    required this.name,
    required this.slug,
    this.description,
    this.iconUrl,
    this.iconName,
    this.subCategories = const [],
  });

  factory ServiceCategoryModel.fromJson(Map<String, dynamic> json) =>
      _$ServiceCategoryModelFromJson(json);

  final String id;
  final String name;
  final String slug;
  final String? description;
  final String? iconUrl;
  final String? iconName;

  final List<ServiceSubCategoryModel> subCategories;

  ServiceCategory toEntity() => ServiceCategory(
    id: id,
    name: name,
    slug: slug,
    description: description,
    iconUrl: iconUrl,
    iconName: iconName,
    subCategories: subCategories.map((s) => s.toEntity()).toList(),
  );
}
