// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'district_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

DistrictModel _$DistrictModelFromJson(Map<String, dynamic> json) =>
    DistrictModel(
      id: json['id'] as String,
      name: json['name'] as String,
      stateId: json['stateId'] as String,
      stateName: json['stateName'] as String,
      centreLatitude: (json['centreLatitude'] as num?)?.toDouble(),
      centreLongitude: (json['centreLongitude'] as num?)?.toDouble(),
    );
