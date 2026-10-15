// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'service_variant_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ServiceVariantModel _$ServiceVariantModelFromJson(
  Map<String, dynamic> json,
) => ServiceVariantModel(
  id: json['id'] as String,
  name: json['name'] as String,
  serviceSubCategoryId: json['serviceSubCategoryId'] as String?,
  serviceSubCategoryName: json['serviceSubCategoryName'] as String?,
  priceType: json['priceType'] as String,
  price: (json['price'] as num).toDouble(),
  description: json['description'] as String?,
  estimatedDurationMinutes: (json['estimatedDurationMinutes'] as num?)?.toInt(),
  media:
      (json['media'] as List<dynamic>?)
          ?.map((e) => ServiceMediaModel.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
);
