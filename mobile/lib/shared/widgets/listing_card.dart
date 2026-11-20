import 'package:flutter/material.dart';
import 'package:zuno/core/theme/app_colors.dart';
import 'package:zuno/shared/widgets/network_photo.dart';

/// An item on a customer's home, search or wishlist — the photo with its price on it, the name,
/// where, and who offers it. One card for grids and sideways strips (the parent gives the width),
/// shared by Rent and Marketplace so both look the same.
class ListingCard extends StatelessWidget {
  const ListingCard({
    required this.imageUrl,
    required this.price,
    required this.title,
    required this.placeLine,
    required this.businessName,
    required this.onTap,
    this.wasPrice,
    this.saving,
    this.rating,
    this.photoCorner,
    this.badge,
    this.dimmed = false,
    super.key,
  });

  /// The photo's full address.
  final String? imageUrl;

  /// The price tag on the photo, e.g. "₹1,200/day" or "₹38 / kg"; null hides the tag.
  final String? price;

  /// The usual price, struck through beside [price] — a food offer's, a product's MRP.
  final String? wasPrice;

  /// The saving in green under the name, e.g. "40% off"; null for none.
  final String? saving;
  final String title;

  /// A line under the name, e.g. the stars.
  final Widget? rating;

  /// "Category · District".
  final String placeLine;
  final String businessName;

  /// Over the photo's top-right corner, e.g. a heart.
  final Widget? photoCorner;

  /// Over the photo's top-left corner, e.g. "Not available".
  final String? badge;

  /// Faded, for something that can no longer be had.
  final bool dimmed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: scheme.onSurfaceVariant,
    );
    final tagStyle = theme.textTheme.labelLarge?.copyWith(
      fontWeight: FontWeight.w800,
      color: scheme.primary,
    );

    final card = Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AspectRatio(
              aspectRatio: 4 / 3,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  NetworkPhoto(url: imageUrl),
                  // The price where the eye lands: on the picture, as a price tag.
                  if (price != null)
                    Positioned(
                      left: 8,
                      bottom: 8,
                      child: _Tag(
                        child: Text.rich(
                          TextSpan(
                            text: price,
                            style: tagStyle,
                            children: [
                              if (wasPrice != null)
                                TextSpan(
                                  text: '  $wasPrice',
                                  style: muted?.copyWith(
                                    decoration: TextDecoration.lineThrough,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  if (badge != null)
                    Positioned(
                      left: 8,
                      top: 8,
                      child: _Tag(
                        child: Text(
                          badge!,
                          style: theme.textTheme.labelSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  if (photoCorner != null)
                    Positioned(top: 4, right: 4, child: photoCorner!),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (saving case final saving?) ...[
                    const SizedBox(height: 2),
                    Text(
                      saving,
                      maxLines: 1,
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: AppColors.status(
                          StatusTone.success,
                          theme.brightness,
                        ),
                      ),
                    ),
                  ],
                  if (rating != null) ...[const SizedBox(height: 2), rating!],
                  const SizedBox(height: 2),
                  _IconLine(
                    icon: Icons.place_outlined,
                    text: placeLine,
                    style: muted,
                  ),
                  if (businessName.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    _IconLine(
                      icon: Icons.storefront_outlined,
                      text: businessName,
                      style: muted,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );

    return dimmed ? Opacity(opacity: 0.55, child: card) : card;
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.94),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: child,
    ),
  );
}

class _IconLine extends StatelessWidget {
  const _IconLine({required this.icon, required this.text, this.style});

  final IconData icon;
  final String text;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, size: 13, color: style?.color),
      const SizedBox(width: 2),
      Expanded(
        child: Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: style,
        ),
      ),
    ],
  );
}
