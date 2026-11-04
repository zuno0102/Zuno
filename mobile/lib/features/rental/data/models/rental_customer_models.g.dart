// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'rental_customer_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

RentalCardModel _$RentalCardModelFromJson(Map<String, dynamic> json) =>
    RentalCardModel(
      id: json['id'] as String,
      name: json['name'] as String,
      categoryName: json['categoryName'] as String,
      priceType: json['priceType'] as String,
      price: (json['price'] as num).toDouble(),
      unitSuffix: json['unitSuffix'] as String? ?? '',
      businessName: json['businessName'] as String? ?? '',
      imageUrl: json['imageUrl'] as String?,
      districtName: json['districtName'] as String?,
    );

RentalHomeSectionModel _$RentalHomeSectionModelFromJson(
  Map<String, dynamic> json,
) => RentalHomeSectionModel(
  code: json['code'] as String,
  title: json['title'] as String,
  layout: json['layout'] as String,
  items:
      (json['items'] as List<dynamic>?)
          ?.map((e) => RentalCardModel.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
);

RentalItemDetailModel _$RentalItemDetailModelFromJson(
  Map<String, dynamic> json,
) => RentalItemDetailModel(
  card: RentalCardModel.fromJson(json['card'] as Map<String, dynamic>),
  priceTypeName: json['priceTypeName'] as String,
  quantityOwned: (json['quantityOwned'] as num).toInt(),
  description: json['description'] as String?,
  subCategoryName: json['subCategoryName'] as String?,
  media:
      (json['media'] as List<dynamic>?)
          ?.map((e) => RentalItemMediaModel.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
  districts:
      (json['districts'] as List<dynamic>?)
          ?.map(
            (e) => RentalItemDistrictModel.fromJson(e as Map<String, dynamic>),
          )
          .toList() ??
      const [],
  questions:
      (json['questions'] as List<dynamic>?)
          ?.map(
            (e) => RentalItemQuestionModel.fromJson(e as Map<String, dynamic>),
          )
          .toList() ??
      const [],
  businessLogoUrl: json['businessLogoUrl'] as String?,
  advanceType: json['advanceType'] as String? ?? 'None',
  advanceAmount: (json['advanceAmount'] as num?)?.toDouble(),
  cancelSteps:
      (json['cancelSteps'] as List<dynamic>?)
          ?.map(
            (e) => RentalCancelStepModel.fromJson(e as Map<String, dynamic>),
          )
          .toList() ??
      const [],
  cancelUnit: json['cancelUnit'] as String? ?? RentalCancelUnit.day,
  cancelChargeType:
      json['cancelChargeType'] as String? ?? RentalCancelChargeType.byTimeLeft,
  cancelPercentPerDay: (json['cancelPercentPerDay'] as num?)?.toDouble(),
  maxCancelPercent: (json['maxCancelPercent'] as num?)?.toDouble() ?? 0,
);
