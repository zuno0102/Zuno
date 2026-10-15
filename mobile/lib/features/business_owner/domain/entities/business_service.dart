import 'package:collection/collection.dart';
import 'package:zuno/features/business_owner/domain/entities/service_district.dart';
import 'package:zuno/features/business_owner/domain/entities/service_media.dart';
import 'package:zuno/features/business_owner/domain/entities/service_question.dart';
import 'package:zuno/features/business_owner/domain/entities/service_variant.dart';

class BusinessService {
  const BusinessService({
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
  final List<ServiceMedia> media;
  final List<ServiceDistrict> targetDistricts;
  final List<ServiceVariant> variants;

  /// What this service asks a customer before they book, in the order the business arranged.
  final List<ServiceQuestion> questions;

  bool get isHourly => priceType == 'Hourly';
  bool get isDaily => priceType == 'Daily';

  ServiceMedia? get video => media.firstWhereOrNull((m) => m.isVideo);

  String? imageUrlForSlot(int slot) =>
      media.firstWhereOrNull((m) => m.isImage && m.sortOrder == slot)?.url;
}
