import 'package:zuno/core/utils/formatting.dart';
import 'package:zuno/features/marketplace/domain/entities/marketplace_post.dart';

/// The words a post's card is made of. Plain functions, so every kind reads the same wherever a
/// post is shown — the business's list now, the customer's screens later.

/// "₹45/kg", "₹4,20,000", "₹180 → ₹99/plate"; null for an advertisement without a price.
String? marketplacePriceLine(MarketplacePost post) {
  final price = post.price;
  if (price == null) return null;
  final unit = post.priceUnit == null ? '' : '/${post.priceUnit}';
  final was = post.originalPrice;
  return was == null
      ? '${rupees(price)}$unit'
      : '${rupees(was)} → ${rupees(price)}$unit';
}

/// "20 portions", "Wholesale · min 100 kg · 2000 kg for sale" — what is on offer and how it sells.
String? marketplaceQuantityLine(
  MarketplacePost post, {
  MarketplaceOptions? options,
}) {
  final unit = post.priceUnit == null ? '' : ' ${post.priceUnit}';
  final condition = post.condition;
  final parts = [
    // "New · 12 in stock", "Used · one piece" — the condition named from the server's table.
    if (condition != null)
      options?.conditions.where((c) => c.code == condition).firstOrNull?.name ??
          condition,
    if (post.keepsStock && !post.isOutOfStock) '${post.quantity} in stock',
    if (condition == MarketplaceItemCondition.used) 'one piece',
    if (post.isFoodOffer && post.quantity != null) '${post.quantity} portions',
    if (post.isWholesale) 'Wholesale',
    if (post.isWholesale && post.minOrderQuantity != null)
      'min ${post.minOrderQuantity}$unit',
    if (!post.isFoodOffer && condition == null && post.quantity != null)
      '${post.quantity}$unit for sale',
  ];
  return parts.isEmpty ? null : parts.join(' · ');
}

/// When a food offer or advertisement runs: "Today 20:00 – 22:00", "17 Jul – 16 Aug".
String? marketplaceWindowLine(MarketplacePost post, {DateTime? now}) {
  final start = post.startsAt;
  final end = post.endsAt;
  if (start == null || end == null) return null;
  if (post.isAdvertisement) {
    return '${formatDayMonth(start)} – ${formatDayMonth(end)}';
  }
  final sameDay =
      start.year == end.year &&
      start.month == end.month &&
      start.day == end.day;
  return sameDay
      ? '${relativeDayLabel(start, now: now)} ${formatTime(start)} – ${formatTime(end)}'
      : '${relativeDayLabel(start, now: now)} ${formatTime(start)} – '
            '${relativeDayLabel(end, now: now)} ${formatTime(end)}';
}

/// The category's details in its own order, with units: "Maruti · 2019 · 48000 km · Petrol".
/// Before the categories load, the values show in the order they came.
String? marketplaceDetailsLine(
  MarketplacePost post,
  List<MarketplaceCategory> categories,
) {
  if (post.attributes.isEmpty) return null;
  final category = categories.where((c) => c.id == post.categoryId).firstOrNull;
  if (category == null) return post.attributes.values.join(' · ');

  final values = [
    for (final f in category.fieldsFor(post.subCategoryId))
      if (post.attributes[f.key] case final value?)
        f.unit == null ? value : '$value ${f.unit}',
  ];
  return values.isEmpty ? null : values.join(' · ');
}
