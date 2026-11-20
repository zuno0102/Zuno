import 'package:flutter/material.dart';
import 'package:zuno/core/theme/app_theme.dart';
import 'package:zuno/shared/widgets/network_photo.dart';

/// An item's photos at the top of its page, swiped sideways, with "2 / 5" in the corner. Empty, it
/// shows the placeholder. [overlay] sits on top, e.g. a heart to save it.
class PhotoGallery extends StatefulWidget {
  const PhotoGallery({
    required this.urls,
    this.aspectRatio = 4 / 3,
    this.overlay,
    super.key,
  });

  /// Full addresses, in order.
  final List<String> urls;
  final double aspectRatio;
  final Widget? overlay;

  @override
  State<PhotoGallery> createState() => _PhotoGalleryState();
}

class _PhotoGalleryState extends State<PhotoGallery> {
  int _photo = 0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final urls = widget.urls;

    return AspectRatio(
      aspectRatio: widget.aspectRatio,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (urls.isEmpty)
            const NetworkPhoto(url: null)
          else
            PageView.builder(
              itemCount: urls.length,
              onPageChanged: (i) => setState(() => _photo = i),
              itemBuilder: (_, i) => NetworkPhoto(url: urls[i]),
            ),
          if (urls.length > 1)
            Positioned(
              right: 12,
              bottom: 12,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  child: Text(
                    '${_photo + 1} / ${urls.length}',
                    style: theme.textTheme.labelMedium,
                  ),
                ),
              ),
            ),
          ?widget.overlay,
        ],
      ),
    );
  }
}
