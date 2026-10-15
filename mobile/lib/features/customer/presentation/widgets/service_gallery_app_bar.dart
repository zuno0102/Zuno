import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:zuno/core/constants/api_constants.dart';
import 'package:zuno/features/customer/domain/entities/service_media.dart';

/// The picture gallery at the top of a service page, collapsing into a plain bar as it scrolls.
///
/// Shared by the service page and by each service inside it, so a customer who opens one of the
/// smaller services gets the same page they came from rather than a stripped-down version of it.
class ServiceGalleryAppBar extends StatefulWidget {
  const ServiceGalleryAppBar({
    required this.images,
    required this.title,
    super.key,
  });

  final List<ServiceMedia> images;
  final String title;

  @override
  State<ServiceGalleryAppBar> createState() => _ServiceGalleryAppBarState();
}

class _ServiceGalleryAppBarState extends State<ServiceGalleryAppBar> {
  int _page = 0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SliverAppBar(
      expandedHeight: 260,
      pinned: true,
      title: Text(widget.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      flexibleSpace: FlexibleSpaceBar(
        background: widget.images.isEmpty
            ? Container(
                color: theme.colorScheme.primaryContainer,
                child: Icon(
                  Icons.image_outlined,
                  size: 48,
                  color: theme.colorScheme.onPrimaryContainer.withValues(
                    alpha: 0.5,
                  ),
                ),
              )
            : Stack(
                fit: StackFit.expand,
                children: [
                  PageView.builder(
                    itemCount: widget.images.length,
                    onPageChanged: (i) => setState(() => _page = i),
                    itemBuilder: (context, index) => CachedNetworkImage(
                      imageUrl:
                          '${ApiConstants.baseUrl}${widget.images[index].url}',
                      fit: BoxFit.cover,
                      errorWidget: (_, _, _) => Container(
                        color: theme.colorScheme.surfaceContainerHighest,
                        child: const Icon(Icons.broken_image_outlined),
                      ),
                    ),
                  ),
                  if (widget.images.length > 1)
                    Positioned(
                      bottom: 12,
                      left: 0,
                      right: 0,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          for (var i = 0; i < widget.images.length; i++)
                            Container(
                              width: i == _page ? 18 : 6,
                              height: 6,
                              margin: const EdgeInsets.symmetric(horizontal: 2),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(
                                  alpha: i == _page ? 0.95 : 0.5,
                                ),
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                        ],
                      ),
                    ),
                ],
              ),
      ),
    );
  }
}
