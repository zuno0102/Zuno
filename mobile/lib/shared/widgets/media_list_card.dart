import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:zuno/core/theme/app_colors.dart';

/// One entry in a business's own list of things it offers — a rent item, a Marketplace post: a
/// square photo, the name, a few lines under it, and a ⋮ menu of what can be done with it.
///
/// Pulled out of the Rent list so every such list in the business panel looks and behaves the
/// same; each list only says what goes in it.
class MediaListCard extends StatelessWidget {
  const MediaListCard({
    required this.title,
    required this.lines,
    required this.placeholderIcon,
    required this.menu,
    required this.onMenuSelected,
    this.thumbnailUrl,
    this.showVideoBadge = false,
    super.key,
  });

  /// The full address of the cover photo, or null to show [placeholderIcon].
  final String? thumbnailUrl;

  final IconData placeholderIcon;

  /// A small camera mark on the photo, for an entry that also has a video.
  final bool showVideoBadge;

  final String title;

  /// The lines under the title, top to bottom.
  final List<Widget> lines;

  /// The ⋮ menu: each entry's value and its words, in order.
  final List<(String, String)> menu;

  final ValueChanged<String> onMenuSelected;

  static const double _thumbnailSize = 48;

  @override
  Widget build(BuildContext context) {
    final url = thumbnailUrl;
    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Stack(
            children: [
              url != null
                  ? CachedNetworkImage(
                      imageUrl: url,
                      width: _thumbnailSize,
                      height: _thumbnailSize,
                      fit: BoxFit.cover,
                      errorWidget: (context, url, error) =>
                          const Icon(Icons.broken_image_outlined),
                    )
                  : Container(
                      width: _thumbnailSize,
                      height: _thumbnailSize,
                      color: Theme.of(
                        context,
                      ).colorScheme.surfaceContainerHighest,
                      child: Icon(placeholderIcon),
                    ),
              if (showVideoBadge)
                Positioned(
                  right: 2,
                  bottom: 2,
                  child: Icon(
                    Icons.videocam,
                    size: 14,
                    color: AppColors.onMedia,
                    shadows: const [Shadow(blurRadius: 3)],
                  ),
                ),
            ],
          ),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final line in lines) ...[const SizedBox(height: 4), line],
          ],
        ),
        isThreeLine: true,
        trailing: menu.isEmpty
            ? null
            : PopupMenuButton<String>(
                onSelected: onMenuSelected,
                itemBuilder: (context) => [
                  for (final (value, label) in menu)
                    PopupMenuItem(value: value, child: Text(label)),
                ],
              ),
      ),
    );
  }
}
