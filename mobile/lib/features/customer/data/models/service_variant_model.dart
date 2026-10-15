import 'package:json_annotation/json_annotation.dart';
import 'package:zuno/features/customer/data/models/service_media_model.dart';
import 'package:zuno/features/customer/domain/entities/service_variant.dart';

part 'service_variant_model.g.dart';

@JsonSerializable(createToJson: false)
class ServiceVariantModel {
  const ServiceVariantModel({
    required this.id,
    required this.name,
    this.serviceSubCategoryId,
    this.serviceSubCategoryName,
    required this.priceType,
    required this.price,
    this.description,
    this.estimatedDurationMinutes,
    this.media = const [],
  });

  factory ServiceVariantModel.fromJson(Map<String, dynamic> json) =>
      _$ServiceVariantModelFromJson(json);

  final String id;
  final String name;
  final String? serviceSubCategoryId;
  final String? serviceSubCategoryName;
  final String? description;
  final String priceType;
  final double price;
  final int? estimatedDurationMinutes;
  final List<ServiceMediaModel> media;

  ServiceVariant toEntity() => ServiceVariant(
    id: id,
    name: name,
    serviceSubCategoryId: serviceSubCategoryId,
    serviceSubCategoryName: serviceSubCategoryName,
    description: description,
    priceType: priceType,
    price: price,
    estimatedDurationMinutes: estimatedDurationMinutes,
    media: media.map((m) => m.toEntity()).toList(),
  );
}
