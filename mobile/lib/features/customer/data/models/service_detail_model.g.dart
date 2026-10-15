// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'service_detail_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ServiceDetailModel _$ServiceDetailModelFromJson(Map<String, dynamic> json) =>
    ServiceDetailModel(
      service: CustomerServiceModel.fromJson(
        json['service'] as Map<String, dynamic>,
      ),
      business: BusinessSummaryModel.fromJson(
        json['business'] as Map<String, dynamic>,
      ),
    );
