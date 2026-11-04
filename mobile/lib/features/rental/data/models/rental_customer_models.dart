import 'package:json_annotation/json_annotation.dart';
import 'package:zuno/features/rental/data/models/rental_models.dart';
import 'package:zuno/features/rental/domain/entities/rental_customer.dart';
import 'package:zuno/features/rental/domain/entities/rental_item.dart';
import 'package:zuno/features/rental/domain/entities/rental_payment.dart';

part 'rental_customer_models.g.dart';

@JsonSerializable(createToJson: false)
class RentalCardModel {
  const RentalCardModel({
    required this.id,
    required this.name,
    required this.categoryName,
    required this.priceType,
    required this.price,
    this.unitSuffix = '',
    this.businessName = '',
    this.imageUrl,
    this.districtName,
  });

  factory RentalCardModel.fromJson(Map<String, dynamic> json) =>
      _$RentalCardModelFromJson(json);

  final String id;
  final String name;
  final String categoryName;
  final String priceType;
  final double price;
  final String unitSuffix;
  final String businessName;
  final String? imageUrl;
  final String? districtName;

  RentalCard toEntity() => RentalCard(
    id: id,
    name: name,
    categoryName: categoryName,
    priceType: priceType,
    price: price,
    unitSuffix: unitSuffix,
    businessName: businessName,
    imageUrl: imageUrl,
    districtName: districtName,
  );
}

@JsonSerializable(createToJson: false)
class RentalHomeSectionModel {
  const RentalHomeSectionModel({
    required this.code,
    required this.title,
    required this.layout,
    this.items = const [],
  });

  factory RentalHomeSectionModel.fromJson(Map<String, dynamic> json) =>
      _$RentalHomeSectionModelFromJson(json);

  final String code;
  final String title;
  final String layout;
  final List<RentalCardModel> items;

  RentalHomeSection toEntity() => RentalHomeSection(
    code: code,
    title: title,
    layout: RentalHomeLayout.from(layout),
    items: items.map((i) => i.toEntity()).toList(),
  );
}

@JsonSerializable(createToJson: false)
class RentalItemDetailModel {
  const RentalItemDetailModel({
    required this.card,
    required this.priceTypeName,
    required this.quantityOwned,
    this.description,
    this.subCategoryName,
    this.media = const [],
    this.districts = const [],
    this.questions = const [],
    this.businessLogoUrl,
    this.advanceType = 'None',
    this.advanceAmount,
    this.cancelSteps = const [],
    this.cancelUnit = RentalCancelUnit.day,
    this.cancelChargeType = RentalCancelChargeType.byTimeLeft,
    this.cancelPercentPerDay,
    this.maxCancelPercent = 0,
  });

  factory RentalItemDetailModel.fromJson(Map<String, dynamic> json) =>
      _$RentalItemDetailModelFromJson(json);

  final RentalCardModel card;
  final String priceTypeName;
  final int quantityOwned;
  final String? description;
  final String? subCategoryName;
  final List<RentalItemMediaModel> media;
  final List<RentalItemDistrictModel> districts;
  final List<RentalItemQuestionModel> questions;
  final String? businessLogoUrl;
  final String advanceType;
  final double? advanceAmount;
  final List<RentalCancelStepModel> cancelSteps;
  final String cancelUnit;
  final String cancelChargeType;
  final double? cancelPercentPerDay;
  final double maxCancelPercent;

  RentalItemDetail toEntity() => RentalItemDetail(
    card: card.toEntity(),
    priceTypeName: priceTypeName,
    quantityOwned: quantityOwned,
    description: description,
    subCategoryName: subCategoryName,
    media: media.map((m) => m.toEntity()).toList(),
    districts: districts.map((d) => d.toEntity()).toList(),
    questions: <RentalItemQuestion>[for (final q in questions) q.toEntity()],
    businessLogoUrl: businessLogoUrl,
    advanceType: advanceType,
    advanceAmount: advanceAmount,
    cancelSteps: cancelSteps.map((s) => s.toEntity()).toList(),
    cancelUnit: cancelUnit,
    cancelChargeType: cancelChargeType,
    cancelPercentPerDay: cancelPercentPerDay,
    maxCancelPercent: maxCancelPercent,
  );
}
