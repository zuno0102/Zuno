import 'package:zuno/core/utils/formatting.dart';
import 'package:zuno/features/customer/domain/entities/business_summary.dart';
import 'package:zuno/features/customer/domain/entities/customer_service.dart';
import 'package:zuno/features/customer/domain/entities/service_media.dart';

/// One service opened on its own, with the business behind it attached.
class ServiceDetail {
  const ServiceDetail({required this.service, required this.business});

  final CustomerService service;
  final BusinessSummary business;

  /// Every picture, in the order the business arranged them — the gallery at the top.
  List<ServiceMedia> get images =>
      service.media.where((m) => m.isImage).toList()
        ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

  bool get hasVariants => service.variants.isNotEmpty;

  /// Whether the service can be ordered as a whole, rather than only one of the things listed inside
  /// it.
  ///
  /// Nearly always yes: the server has never required a sub-service, and a customer who wants the
  /// whole job needs somewhere to say so. The exception is a service priced at nothing, which happens
  /// when a business sells only through the items beneath it — ordering that would place an order for
  /// ₹0, so the page offers the items instead and says nothing about the parent.
  bool get canBookServiceItself => service.price > 0 || !hasVariants;

  // No coverage line here any more. The districts a business works in decide which services a
  // customer is shown at all, so by the time this page opens that filter has already run — printing
  // it back reads as a restriction on a page they only reached because they were inside it. The
  // districts stay on the service for the matching that still depends on them.

  /// What the price line should say. With packages the service price is a starting point,
  /// because the customer books a package rather than the service itself.
  String get priceLabel {
    final lowest = service.lowestVariantPrice ?? service.price;
    final prefix = hasVariants ? 'From ' : '';
    return '$prefix${rupees(lowest)}${priceUnitSuffix(service.priceType)}';
  }

}
