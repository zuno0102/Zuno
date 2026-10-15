import 'package:json_annotation/json_annotation.dart';
import 'package:zuno/features/business_owner/data/models/service_district_model.dart';
import 'package:zuno/features/business_owner/data/models/service_media_model.dart';
import 'package:zuno/features/business_owner/data/models/service_question_model.dart';
import 'package:zuno/features/business_owner/data/models/service_variant_model.dart';
import 'package:zuno/features/business_owner/domain/entities/business_service.dart';

part 'business_service_model.g.dart';

@JsonSerializable(createToJson: false)
class BusinessServiceModel {
  const BusinessServiceModel({
    required this.id,
    required this.serviceCategoryId,
    required this.serviceCategoryName,
    required this.name,
    required this.priceType,
    required this.price,
    required this.isActive,
    this.requiredWorkerCount = 1,
    this.itemName,
    this.description,
    this.estimatedDurationMinutes,
    this.media = const [],
    this.targetDistricts = const [],
    this.variants = const [],
    this.questions = const [],
  });

  factory BusinessServiceModel.fromJson(Map<String, dynamic> json) =>
      _$BusinessServiceModelFromJson(json);

  final String id;
  final String serviceCategoryId;
  final String serviceCategoryName;
  final String name;
  final String? itemName;
  final String? description;
  final String priceType;
  final double price;
  final int? estimatedDurationMinutes;
  final bool isActive;
  final int requiredWorkerCount;
  final List<ServiceMediaModel> media;
  final List<ServiceDistrictModel> targetDistricts;
  final List<ServiceVariantModel> variants;
  final List<ServiceQuestionModel> questions;

  BusinessService toEntity() => BusinessService(
    id: id,
    serviceCategoryId: serviceCategoryId,
    serviceCategoryName: serviceCategoryName,
    name: name,
    itemName: itemName,
    description: description,
    priceType: priceType,
    price: price,
    estimatedDurationMinutes: estimatedDurationMinutes,
    isActive: isActive,
    requiredWorkerCount: requiredWorkerCount,
    media: media.map((m) => m.toEntity()).toList(),
    targetDistricts: targetDistricts.map((d) => d.toEntity()).toList(),
    variants: variants.map((v) => v.toEntity()).toList(),
    questions: questions.map((q) => q.toEntity()).toList(),
  );
}
