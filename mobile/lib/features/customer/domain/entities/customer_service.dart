import 'package:collection/collection.dart';
import 'package:zuno/features/customer/domain/entities/service_district.dart';
import 'package:zuno/features/customer/domain/entities/service_media.dart';
import 'package:zuno/features/customer/domain/entities/service_question.dart';
import 'package:zuno/features/customer/domain/entities/service_variant.dart';

class CustomerService {
  const CustomerService({
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

  final String id;
  final String serviceCategoryName;
  final String name;
  final String? description;
  final String priceType;
  final double price;
  final int? estimatedDurationMinutes;
  final List<ServiceMedia> media;
  final List<ServiceDistrict> targetDistricts;
  final List<ServiceVariant> variants;

  /// What the business needs to know before it can staff this job.
  final List<ServiceQuestion> questions;

  bool get isHourly => priceType == 'Hourly';
  bool get isDaily => priceType == 'Daily';

  ServiceMedia? get video => media.firstWhereOrNull((m) => m.isVideo);

  String? imageUrlForSlot(int slot) =>
      media.firstWhereOrNull((m) => m.isImage && m.sortOrder == slot)?.url;

  /// The lowest variant price, for the "From ₹X" summary shown on the service tile when the
  /// service has variants (each variant is individually priced/bookable — the parent service
  /// itself isn't directly bookable in that case).
  double? get lowestVariantPrice => variants.isEmpty
      ? null
      : variants.map((v) => v.price).reduce((a, b) => a < b ? a : b);
}
