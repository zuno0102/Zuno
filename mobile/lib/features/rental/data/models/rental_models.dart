import 'package:json_annotation/json_annotation.dart';
import 'package:zuno/features/rental/domain/entities/rental_item.dart';
import 'package:zuno/features/rental/domain/entities/rental_payment.dart';
import 'package:zuno/shared/domain/star_rating.dart';

part 'rental_models.g.dart';

@JsonSerializable(createToJson: false)
class RentalItemMediaModel {
  const RentalItemMediaModel({
    required this.id,
    required this.mediaType,
    required this.url,
    required this.sortOrder,
  });

  factory RentalItemMediaModel.fromJson(Map<String, dynamic> json) =>
      _$RentalItemMediaModelFromJson(json);

  final String id;
  final String mediaType;
  final String url;
  final int sortOrder;

  RentalItemMedia toEntity() => RentalItemMedia(
    id: id,
    mediaType: mediaType,
    url: url,
    sortOrder: sortOrder,
  );
}

@JsonSerializable(createToJson: false)
class RentalItemDistrictModel {
  const RentalItemDistrictModel({
    required this.id,
    required this.name,
    required this.stateId,
    required this.stateName,
  });

  factory RentalItemDistrictModel.fromJson(Map<String, dynamic> json) =>
      _$RentalItemDistrictModelFromJson(json);

  final String id;
  final String name;
  final String stateId;
  final String stateName;

  RentalItemDistrict toEntity() => RentalItemDistrict(
    id: id,
    name: name,
    stateId: stateId,
    stateName: stateName,
  );
}

@JsonSerializable(createToJson: false)
class RentalItemQuestionModel {
  const RentalItemQuestionModel({
    required this.id,
    required this.prompt,
    required this.isRequired,
  });

  factory RentalItemQuestionModel.fromJson(Map<String, dynamic> json) =>
      _$RentalItemQuestionModelFromJson(json);

  final String id;
  final String prompt;
  final bool isRequired;

  RentalItemQuestion toEntity() =>
      RentalItemQuestion(id: id, prompt: prompt, isRequired: isRequired);
}

@JsonSerializable(createToJson: false)
class RentalPriceTypeModel {
  const RentalPriceTypeModel({
    required this.code,
    required this.name,
    required this.detail,
    required this.unitSuffix,
  });

  factory RentalPriceTypeModel.fromJson(Map<String, dynamic> json) =>
      _$RentalPriceTypeModelFromJson(json);

  final String code;
  final String name;
  final String detail;
  final String unitSuffix;

  RentalPriceTypeOption toEntity() => RentalPriceTypeOption(
    code: code,
    name: name,
    detail: detail,
    unitSuffix: unitSuffix,
  );
}

@JsonSerializable(createToJson: false)
class RentalItemModel {
  const RentalItemModel({
    required this.id,
    required this.rentalCategoryId,
    required this.rentalCategoryName,
    required this.name,
    required this.priceType,
    required this.price,
    required this.quantityOwned,
    required this.isAvailable,
    this.rentalSubCategoryId,
    this.rentalSubCategoryName,
    this.description,
    this.media = const [],
    this.districts = const [],
    this.questions = const [],
    this.advanceType = 'None',
    this.advanceAmount,
    this.cancelSteps = const [],
    this.cancelUnit = RentalCancelUnit.day,
    this.cancelChargeType = RentalCancelChargeType.byTimeLeft,
    this.cancelPercentPerDay,
    this.ratingAverage,
    this.ratingCount = 0,
  });

  factory RentalItemModel.fromJson(Map<String, dynamic> json) =>
      _$RentalItemModelFromJson(json);

  final String id;
  final String rentalCategoryId;
  final String rentalCategoryName;
  final String? rentalSubCategoryId;
  final String? rentalSubCategoryName;
  final String name;
  final String? description;
  final String priceType;
  final double price;
  final int quantityOwned;
  final bool isAvailable;
  final List<RentalItemMediaModel> media;
  final List<RentalItemDistrictModel> districts;
  final List<RentalItemQuestionModel> questions;
  final String advanceType;
  final double? advanceAmount;
  final List<RentalCancelStepModel> cancelSteps;
  final String cancelUnit;
  final String cancelChargeType;
  final double? cancelPercentPerDay;

  /// The item's own stars; null until it has enough ratings to be fair.
  final double? ratingAverage;
  final int ratingCount;

  RentalItem toEntity() => RentalItem(
    id: id,
    rentalCategoryId: rentalCategoryId,
    rentalCategoryName: rentalCategoryName,
    rentalSubCategoryId: rentalSubCategoryId,
    rentalSubCategoryName: rentalSubCategoryName,
    name: name,
    description: description,
    priceType: priceType,
    price: price,
    quantityOwned: quantityOwned,
    isAvailable: isAvailable,
    media: media.map((m) => m.toEntity()).toList(),
    districts: districts.map((d) => d.toEntity()).toList(),
    questions: questions.map((q) => q.toEntity()).toList(),
    advanceType: advanceType,
    advanceAmount: advanceAmount,
    cancelSteps: cancelSteps.map((s) => s.toEntity()).toList(),
    cancelUnit: cancelUnit,
    cancelChargeType: cancelChargeType,
    cancelPercentPerDay: cancelPercentPerDay,
    rating: StarRating(average: ratingAverage, count: ratingCount),
  );
}

@JsonSerializable(createToJson: false)
class RentalItemPageModel {
  const RentalItemPageModel({
    required this.items,
    required this.page,
    required this.pageSize,
    required this.totalCount,
  });

  factory RentalItemPageModel.fromJson(Map<String, dynamic> json) =>
      _$RentalItemPageModelFromJson(json);

  final List<RentalItemModel> items;
  final int page;
  final int pageSize;
  final int totalCount;
}

@JsonSerializable(createToJson: false)
class RentalSummaryModel {
  const RentalSummaryModel({
    required this.totalItems,
    required this.availableItems,
    required this.unavailableItems,
    required this.unitsAvailable,
  });

  factory RentalSummaryModel.fromJson(Map<String, dynamic> json) =>
      _$RentalSummaryModelFromJson(json);

  final int totalItems;
  final int availableItems;
  final int unavailableItems;
  final int unitsAvailable;

  RentalSummary toEntity() => RentalSummary(
    totalItems: totalItems,
    availableItems: availableItems,
    unavailableItems: unavailableItems,
    unitsAvailable: unitsAvailable,
  );
}

@JsonSerializable(createToJson: false)
class RentalSubCategoryModel {
  const RentalSubCategoryModel({
    required this.id,
    required this.name,
    this.maxCancelPercent = 0,
  });

  factory RentalSubCategoryModel.fromJson(Map<String, dynamic> json) =>
      _$RentalSubCategoryModelFromJson(json);

  final String id;
  final String name;
  final double maxCancelPercent;

  RentalSubCategory toEntity() =>
      RentalSubCategory(id: id, name: name, maxCancelPercent: maxCancelPercent);
}

@JsonSerializable(createToJson: false)
class RentalCategoryModel {
  const RentalCategoryModel({
    required this.id,
    required this.name,
    this.iconName,
    this.subCategories = const [],
    this.maxCancelPercent = 0,
  });

  factory RentalCategoryModel.fromJson(Map<String, dynamic> json) =>
      _$RentalCategoryModelFromJson(json);

  final String id;
  final String name;
  final String? iconName;
  final List<RentalSubCategoryModel> subCategories;
  final double maxCancelPercent;

  RentalCategory toEntity() => RentalCategory(
    id: id,
    name: name,
    iconName: iconName,
    subCategories: subCategories.map((s) => s.toEntity()).toList(),
    maxCancelPercent: maxCancelPercent,
  );
}

@JsonSerializable(createToJson: false)
class RentalCancelStepModel {
  const RentalCancelStepModel({
    required this.unitsBefore,
    required this.percent,
  });

  factory RentalCancelStepModel.fromJson(Map<String, dynamic> json) =>
      _$RentalCancelStepModelFromJson(json);

  final int unitsBefore;
  final double percent;

  RentalCancelStep toEntity() =>
      RentalCancelStep(unitsBefore: unitsBefore, percent: percent);
}
