import 'package:json_annotation/json_annotation.dart';
import 'package:zuno/features/business_owner/domain/entities/service_media.dart';

part 'service_media_model.g.dart';

@JsonSerializable(createToJson: false)
class ServiceMediaModel {
  const ServiceMediaModel({
    required this.id,
    required this.mediaType,
    required this.url,
    required this.sortOrder,
  });

  factory ServiceMediaModel.fromJson(Map<String, dynamic> json) =>
      _$ServiceMediaModelFromJson(json);

  final String id;
  final String mediaType;
  final String url;
  final int sortOrder;

  ServiceMedia toEntity() => ServiceMedia(
    id: id,
    mediaType: mediaType,
    url: url,
    sortOrder: sortOrder,
  );
}
