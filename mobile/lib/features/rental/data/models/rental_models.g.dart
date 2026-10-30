// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'rental_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

RentalItemMediaModel _$RentalItemMediaModelFromJson(
  Map<String, dynamic> json,
) => RentalItemMediaModel(
  id: json['id'] as String,
  mediaType: json['mediaType'] as String,
  url: json['url'] as String,
  sortOrder: (json['sortOrder'] as num).toInt(),
);

RentalItemDistrictModel _$RentalItemDistrictModelFromJson(
  Map<String, dynamic> json,
) => RentalItemDistrictModel(
  id: json['id'] as String,
  name: json['name'] as String,
  stateId: json['stateId'] as String,
  stateName: json['stateName'] as String,
);

RentalItemQuestionModel _$RentalItemQuestionModelFromJson(
  Map<String, dynamic> json,
) => RentalItemQuestionModel(
  id: json['id'] as String,
  prompt: json['prompt'] as String,
  isRequired: json['isRequired'] as bool,
);

RentalPriceTypeModel _$RentalPriceTypeModelFromJson(
  Map<String, dynamic> json,
) => RentalPriceTypeModel(
  code: json['code'] as String,
  name: json['name'] as String,
  detail: json['detail'] as String,
  unitSuffix: json['unitSuffix'] as String,
);

RentalItemModel _$RentalItemModelFromJson(Map<String, dynamic> json) =>
    RentalItemModel(
      id: json['id'] as String,
      rentalCategoryId: json['rentalCategoryId'] as String,
      rentalCategoryName: json['rentalCategoryName'] as String,
      name: json['name'] as String,
      priceType: json['priceType'] as String,
      price: (json['price'] as num).toDouble(),
      quantityOwned: (json['quantityOwned'] as num).toInt(),
      isAvailable: json['isAvailable'] as bool,
      rentalSubCategoryId: json['rentalSubCategoryId'] as String?,
      rentalSubCategoryName: json['rentalSubCategoryName'] as String?,
      description: json['description'] as String?,
      media:
          (json['media'] as List<dynamic>?)
              ?.map(
                (e) => RentalItemMediaModel.fromJson(e as Map<String, dynamic>),
              )
              .toList() ??
          const [],
      districts:
          (json['districts'] as List<dynamic>?)
              ?.map(
                (e) =>
                    RentalItemDistrictModel.fromJson(e as Map<String, dynamic>),
              )
              .toList() ??
          const [],
      questions:
          (json['questions'] as List<dynamic>?)
              ?.map(
                (e) =>
                    RentalItemQuestionModel.fromJson(e as Map<String, dynamic>),
              )
              .toList() ??
          const [],
      advanceType: json['advanceType'] as String? ?? 'None',
      advanceAmount: (json['advanceAmount'] as num?)?.toDouble(),
    );

RentalItemPageModel _$RentalItemPageModelFromJson(Map<String, dynamic> json) =>
    RentalItemPageModel(
      items: (json['items'] as List<dynamic>)
          .map((e) => RentalItemModel.fromJson(e as Map<String, dynamic>))
          .toList(),
      page: (json['page'] as num).toInt(),
      pageSize: (json['pageSize'] as num).toInt(),
      totalCount: (json['totalCount'] as num).toInt(),
    );

RentalSummaryModel _$RentalSummaryModelFromJson(Map<String, dynamic> json) =>
    RentalSummaryModel(
      totalItems: (json['totalItems'] as num).toInt(),
      availableItems: (json['availableItems'] as num).toInt(),
      unavailableItems: (json['unavailableItems'] as num).toInt(),
      unitsAvailable: (json['unitsAvailable'] as num).toInt(),
    );

RentalSubCategoryModel _$RentalSubCategoryModelFromJson(
  Map<String, dynamic> json,
) => RentalSubCategoryModel(
  id: json['id'] as String,
  name: json['name'] as String,
);

RentalCategoryModel _$RentalCategoryModelFromJson(Map<String, dynamic> json) =>
    RentalCategoryModel(
      id: json['id'] as String,
      name: json['name'] as String,
      iconName: json['iconName'] as String?,
      subCategories:
          (json['subCategories'] as List<dynamic>?)
              ?.map(
                (e) =>
                    RentalSubCategoryModel.fromJson(e as Map<String, dynamic>),
              )
              .toList() ??
          const [],
    );
