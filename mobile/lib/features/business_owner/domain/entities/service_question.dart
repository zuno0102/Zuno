/// One box a business wants the customer to fill in when booking this service.
///
/// The business writes these itself — a caterer asks for the dish count and servings, a painter
/// asks for wall sizes. Nothing here is fixed by the app; the booking form draws whatever the
/// business typed.
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

  /// Whether the customer must answer before the order can be placed.
  final bool isRequired;

  final int sortOrder;
}
