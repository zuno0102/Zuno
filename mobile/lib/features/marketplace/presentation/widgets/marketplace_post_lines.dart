import 'package:zuno/core/utils/formatting.dart';
import 'package:zuno/features/marketplace/domain/entities/marketplace_post.dart';

/// The words a post's card is made of. Plain functions, so every kind reads the same wherever a
/// post is shown — the business's list now, the customer's screens later.

/// "₹45/kg", "₹4,20,000", "₹180 → ₹99/plate", "₹449 – ₹499" for colours priced apart; null for an
/// advertisement without a price.
String? marketplacePriceLine(MarketplacePost post) {
  final price = post.price;
  if (price == null) return null;
  final unit = post.priceUnit == null ? '' : '/${post.priceUnit}';
  final prices = [for (final v in post.variants) v.price ?? price];
  final highest = prices.fold(price, (a, b) => b > a ? b : a);
  final lowest = prices.fold(price, (a, b) => b < a ? b : a);
  final now = highest > lowest
      ? '${rupees(lowest)} – ${rupees(highest)}'
      : rupees(price);
  final was = post.originalPrice;
  if (was == null) return '$now$unit';
  // A product's offer against its MRP; a food offer already reads as usual → offer price.
  final offer = post.condition == null
      ? null
      : marketplaceOfferPercent(lowest, was);
  return '${rupees(was)} → $now$unit${offer == null ? '' : ' · $offer% off'}';
}

/// How much below the MRP a price is, in whole per cent — 25 for ₹449 against ₹599; null without
/// an MRP, or when the price is not below it.
int? marketplaceOfferPercent(double? price, double? mrp) {
  if (price == null || mrp == null || mrp <= 0 || price >= mrp) return null;
  final percent = ((mrp - price) / mrp * 100).round();
  return percent == 0 ? null : percent;
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
    // "Pack of 3": how many come in one; a single piece goes unsaid.
    if ((post.packQuantity ?? 1) > 1) 'Pack of ${post.packQuantity}',
    if (post.keepsStock && !post.isOutOfStock) '${post.quantity} in stock',
    if (post.variants.isNotEmpty)
      post.variants.length == 1
          ? '1 colour / size'
          : '${post.variants.length} colours / sizes',
    // "1 inactive": colours / sizes switched off, kept but not on sale. The main product (the
    // first) is never one of them — the post's own switch is its on/off.
    if (post.variants.skip(1).where((v) => !v.isActive).length case final off
        when off > 0)
      '$off inactive',
    // "1 out of stock": the main or a colour / size on sale at 0, while the product as a whole
    // still has stock (then the card's own "Out of stock" says it).
    if (!post.isOutOfStock && _emptyOnSale(post) > 0)
      '${_emptyOnSale(post)} out of stock',
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

/// How many of a product's items on sale — the main product, and each colour / size switched on —
/// are at 0. Each keeps its own count: main 50 with Green at 0 is "1 out of stock".
int _emptyOnSale(MarketplacePost post) => [
  ...post.variants.take(1),
  ...post.variants.skip(1).where((v) => v.isActive),
].where((v) => v.stock <= 0).length;
