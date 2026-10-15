// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'customer_service_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CustomerServiceModel _$CustomerServiceModelFromJson(
  Map<String, dynamic> json,
) => CustomerServiceModel(
  id: json['id'] as String,
  serviceCategoryName: json['serviceCategoryName'] as String,
  name: json['name'] as String,
  priceType: json['priceType'] as String,
  price: (json['price'] as num).toDouble(),
  description: json['description'] as String?,
  estimatedDurationMinutes: (json['estimatedDurationMinutes'] as num?)?.toInt(),
  media:
      (json['media'] as List<dynamic>?)
          ?.map((e) => ServiceMediaModel.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
  targetDistricts:
      (json['targetDistricts'] as List<dynamic>?)
          ?.map((e) => ServiceDistrictModel.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
  variants:
      (json['variants'] as List<dynamic>?)
          ?.map((e) => ServiceVariantModel.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
  questions:
      (json['questions'] as List<dynamic>?)
          ?.map((e) => ServiceQuestionModel.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
);
