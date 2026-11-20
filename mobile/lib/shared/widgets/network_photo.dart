import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// A photo from one of Zuno's servers, cached, or a quiet placeholder while it loads, when it fails
/// and when there is none. The caller resolves the full address (each server has its own base).
class NetworkPhoto extends StatelessWidget {
  const NetworkPhoto({
    required this.url,
    this.fit = BoxFit.cover,
    this.placeholderIcon = Icons.inventory_2_outlined,
    super.key,
  });

  /// The full address; null or empty shows the placeholder.
  final String? url;
  final BoxFit fit;
  final IconData placeholderIcon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final placeholder = ColoredBox(
      color: scheme.surfaceContainerHighest,
      child: Icon(placeholderIcon, size: 36, color: scheme.onSurfaceVariant),
    );
    final value = url;
    if (value == null || value.isEmpty) return placeholder;

    return CachedNetworkImage(
      imageUrl: value,
      fit: fit,
      placeholder: (_, _) => placeholder,
      errorWidget: (_, _, _) => placeholder,
    );
  }
}
