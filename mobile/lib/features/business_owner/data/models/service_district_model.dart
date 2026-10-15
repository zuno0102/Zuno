import 'package:json_annotation/json_annotation.dart';
import 'package:zuno/features/business_owner/domain/entities/service_district.dart';

part 'service_district_model.g.dart';

@JsonSerializable(createToJson: false)
class ServiceDistrictModel {
  const ServiceDistrictModel({
    required this.id,
    required this.name,
    required this.stateId,
    required this.stateName,
  });

  factory ServiceDistrictModel.fromJson(Map<String, dynamic> json) =>
      _$ServiceDistrictModelFromJson(json);

  final String id;
  final String name;
  final String stateId;
  final String stateName;

  ServiceDistrict toEntity() => ServiceDistrict(
    id: id,
    name: name,
    stateId: stateId,
    stateName: stateName,
  );
}
