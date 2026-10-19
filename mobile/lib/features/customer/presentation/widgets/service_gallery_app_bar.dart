import 'dart:math' as math;
import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:zuno/core/constants/api_constants.dart';
import 'package:zuno/core/theme/app_colors.dart';
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
    final screen = MediaQuery.sizeOf(context);
    final topInset = MediaQuery.paddingOf(context).top;

    // Sized from the screen rather than fixed at 260.
    //
    // A service is chosen on the strength of its photograph, and a fixed 260 gave it a letterbox
    // on every phone — too short to show the work, while the page underneath ran out of content
    // and left a band of empty white below the fold. Nine-tenths of the width is roughly a 10:9
    // frame, which suits the way people photograph a room or a finished job; the half-screen cap
    // keeps the price and the Book button in view on a short phone, which matters more than the
    // picture does.
    final expandedHeight = math.min(screen.width * 0.9, screen.height * 0.5);

    return SliverAppBar(
      expandedHeight: expandedHeight,
      pinned: true,
      flexibleSpace: LayoutBuilder(
        builder: (context, constraints) {
          // Within a few pixels of collapsed, allowing for the rounding that comes out of a
          // scroll in progress.
          final isCollapsed =
              constraints.maxHeight <= kToolbarHeight + topInset + 8;

          return FlexibleSpaceBar(
            // Named only once the picture has gone.
            //
            // The title used to be set on the app bar itself, which draws it over the photograph
            // the whole time it is expanded: dark text on whatever happened to be in the middle
            // of the image, beside the back arrow, and repeating the heading the page already
            // shows an inch below it. Here it appears as the bar closes, where it is the only
            // thing naming what you are looking at.
            title: isCollapsed
                ? Text(
                    widget.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurface,
                    ),
                  )
                : null,
            titlePadding: const EdgeInsetsDirectional.only(
              start: 56,
              end: 16,
              bottom: 14,
            ),
            background: _Gallery(
              images: widget.images,
              page: _page,
              onPageChanged: (i) => setState(() => _page = i),
            ),
          );
        },
      ),
    );
  }
}

class _Gallery extends StatelessWidget {
  const _Gallery({
    required this.images,
    required this.page,
    required this.onPageChanged,
  });

  final List<ServiceMedia> images;
  final int page;
  final ValueChanged<int> onPageChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (images.isEmpty) {
      return Container(
        color: theme.colorScheme.primaryContainer,
        child: Icon(
          Icons.image_outlined,
          size: 48,
          color: theme.colorScheme.onPrimaryContainer.withValues(alpha: 0.5),
        ),
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        PageView.builder(
          itemCount: images.length,
          onPageChanged: onPageChanged,
          itemBuilder: (context, index) =>
              _Photograph(url: '${ApiConstants.baseUrl}${images[index].url}'),
        ),

        // A wash under the back arrow, which otherwise sits on bare photograph and disappears
        // against anything pale.
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: kToolbarHeight + MediaQuery.paddingOf(context).top,
          child: const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [AppColors.scrim, Colors.transparent],
              ),
            ),
          ),
        ),

        if (images.length > 1)
          Positioned(
            bottom: 12,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < images.length; i++)
                  Container(
                    width: i == page ? 18 : 6,
                    height: 6,
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(
                        alpha: i == page ? 0.95 : 0.5,
                      ),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

/// One picture, shown whole.
///
/// Cropping it to fill the frame was losing the subject: a photograph taken in portrait, or of a
/// wall with the work along one edge, came out as a close-up of its own middle. The picture is
/// fitted inside the frame instead, and a blurred, enlarged copy of itself fills what is left —
/// so nothing is cut off and the gaps still belong to the image rather than reading as a mistake.
class _Photograph extends StatelessWidget {
  const _Photograph({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    Widget broken() => Container(
      color: theme.colorScheme.surfaceContainerHighest,
      child: const Icon(Icons.broken_image_outlined),
    );

    return Stack(
      fit: StackFit.expand,
      children: [
        ImageFiltered(
          imageFilter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: CachedNetworkImage(
            imageUrl: url,
            fit: BoxFit.cover,
            errorWidget: (_, _, _) => broken(),
          ),
        ),
        CachedNetworkImage(
          imageUrl: url,
          fit: BoxFit.contain,
          errorWidget: (_, _, _) => broken(),
        ),
      ],
    );
  }
}
