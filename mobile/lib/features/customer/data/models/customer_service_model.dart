import 'package:json_annotation/json_annotation.dart';
import 'package:zuno/features/customer/data/models/service_district_model.dart';
import 'package:zuno/features/customer/data/models/service_media_model.dart';
import 'package:zuno/features/customer/data/models/service_question_model.dart';
import 'package:zuno/features/customer/data/models/service_variant_model.dart';
import 'package:zuno/features/customer/domain/entities/customer_service.dart';

part 'customer_service_model.g.dart';

@JsonSerializable(createToJson: false)
class CustomerServiceModel {
  const CustomerServiceModel({
    required this.id,
    required this.serviceCategoryName,
    required this.name,
    required this.priceType,
    required this.price,
    this.description,
    this.estimatedDurationMinutes,
    this.media = const [],
    this.targetDistricts = const [],
    this.variants = const [],
    this.questions = const [],
  });

  factory CustomerServiceModel.fromJson(Map<String, dynamic> json) =>
      _$CustomerServiceModelFromJson(json);

  final String id;
  final String serviceCategoryName;
  final String name;
  final String? description;
  final String priceType;
  final double price;
  final int? estimatedDurationMinutes;
  final List<ServiceMediaModel> media;
  final List<ServiceDistrictModel> targetDistricts;
  final List<ServiceVariantModel> variants;
  final List<ServiceQuestionModel> questions;

  CustomerService toEntity() => CustomerService(
    id: id,
    serviceCategoryName: serviceCategoryName,
    name: name,
    description: description,
    priceType: priceType,
    price: price,
    estimatedDurationMinutes: estimatedDurationMinutes,
    media: media.map((m) => m.toEntity()).toList(),
    targetDistricts: targetDistricts.map((d) => d.toEntity()).toList(),
    variants: variants.map((v) => v.toEntity()).toList(),
    questions: questions.map((q) => q.toEntity()).toList(),
  );
}
