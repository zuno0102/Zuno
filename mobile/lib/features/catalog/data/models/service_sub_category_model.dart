import 'package:json_annotation/json_annotation.dart';
import 'package:zuno/features/catalog/domain/entities/service_sub_category.dart';

part 'service_sub_category_model.g.dart';

@JsonSerializable(createToJson: false)
class ServiceSubCategoryModel {
  const ServiceSubCategoryModel({
    required this.id,
    required this.serviceCategoryId,
    required this.name,
    required this.slug,
  });

  factory ServiceSubCategoryModel.fromJson(Map<String, dynamic> json) =>
      _$ServiceSubCategoryModelFromJson(json);

  final String id;
  final String serviceCategoryId;
  final String name;
  final String slug;

  ServiceSubCategory toEntity() => ServiceSubCategory(
    id: id,
    serviceCategoryId: serviceCategoryId,
    name: name,
    slug: slug,
  );
}
