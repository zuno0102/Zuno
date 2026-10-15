import 'package:collection/collection.dart';
import 'package:zuno/features/business_owner/domain/entities/service_media.dart';

class ServiceVariant {
  const ServiceVariant({
    required this.id,
    required this.name,
    this.serviceSubCategoryId,
    this.serviceSubCategoryName,
    required this.priceType,
    required this.price,
    required this.isActive,
    this.description,
    this.estimatedDurationMinutes,
    this.media = const [],
  });

  final String id;
  final String name;

  /// The kind of work this item is, within the parent service's category.
  final String? serviceSubCategoryId;
  final String? serviceSubCategoryName;
  final String? description;
  final String priceType;
  final double price;
  final int? estimatedDurationMinutes;
  final bool isActive;
  final List<ServiceMedia> media;

  bool get isHourly => priceType == 'Hourly';
  bool get isDaily => priceType == 'Daily';

  ServiceMedia? get video => media.firstWhereOrNull((m) => m.isVideo);

  String? imageUrlForSlot(int slot) =>
      media.firstWhereOrNull((m) => m.isImage && m.sortOrder == slot)?.url;
}
