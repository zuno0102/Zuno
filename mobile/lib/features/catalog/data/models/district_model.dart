import 'package:json_annotation/json_annotation.dart';
import 'package:zuno/features/catalog/domain/entities/district.dart';

part 'district_model.g.dart';

@JsonSerializable(createToJson: false)
class DistrictModel {
  const DistrictModel({
    required this.id,
    required this.name,
    required this.stateId,
    required this.stateName,
    this.centreLatitude,
    this.centreLongitude,
  });

  factory DistrictModel.fromJson(Map<String, dynamic> json) =>
      _$DistrictModelFromJson(json);

  final String id;
  final String name;
  final String stateId;
  final String stateName;
  final double? centreLatitude;
  final double? centreLongitude;

  District toEntity() => District(
    id: id,
    name: name,
    stateId: stateId,
    stateName: stateName,
    centreLatitude: centreLatitude,
    centreLongitude: centreLongitude,
  );
}
