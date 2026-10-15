import 'package:json_annotation/json_annotation.dart';
import 'package:zuno/features/customer/data/models/business_summary_model.dart';
import 'package:zuno/features/customer/data/models/customer_service_model.dart';
import 'package:zuno/features/customer/domain/entities/service_detail.dart';

part 'service_detail_model.g.dart';

@JsonSerializable(createToJson: false)
class ServiceDetailModel {
  const ServiceDetailModel({required this.service, required this.business});

  factory ServiceDetailModel.fromJson(Map<String, dynamic> json) =>
      _$ServiceDetailModelFromJson(json);

  final CustomerServiceModel service;
  final BusinessSummaryModel business;

  ServiceDetail toEntity() =>
      ServiceDetail(service: service.toEntity(), business: business.toEntity());
}
