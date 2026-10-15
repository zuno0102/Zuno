import 'package:json_annotation/json_annotation.dart';
import 'package:zuno/features/catalog/domain/entities/location_state.dart';

part 'location_state_model.g.dart';

@JsonSerializable(createToJson: false)
class LocationStateModel {
  const LocationStateModel({required this.id, required this.name});

  factory LocationStateModel.fromJson(Map<String, dynamic> json) =>
      _$LocationStateModelFromJson(json);

  final String id;
  final String name;

  LocationState toEntity() => LocationState(id: id, name: name);
}
