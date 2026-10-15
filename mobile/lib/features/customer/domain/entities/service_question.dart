/// One box the business wants filled in when booking this service.
///
/// Deliberately a second copy of the business-side entity rather than a shared one. The customer
/// and business features already keep their own `service_variant`, `service_media` and
/// `service_district` for the same reason: the two sides are free to diverge without one
/// dragging the other with it. Do not "fix" this by merging them.
class ServiceQuestion {
  const ServiceQuestion({
    required this.id,
    required this.prompt,
    required this.isRequired,
    required this.sortOrder,
  });

  final String id;

  /// What the customer is asked, in the business's own words.
  final String prompt;

  /// Whether an answer is needed before the order can be placed.
  final bool isRequired;

  final int sortOrder;
}
