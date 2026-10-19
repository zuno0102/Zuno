import 'dart:math' as math;
import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:zuno/core/constants/api_constants.dart';
import 'package:zuno/features/customer/domain/entities/service_media.dart';

/// The bar and the picture gallery at the top of a service page.
///
/// Shared by the service page and by each service inside it, so a customer who opens one of the
/// smaller services gets the same page they came from rather than a stripped-down version of it.
///
/// The bar is its own white strip above the picture rather than floating on top of it. Drawn over
/// the photograph it needed a dark wash behind the back arrow to stay legible, the service name
/// sat across whatever happened to be in the middle of the image, and that name was already the
/// heading an inch below. On its own strip none of that is needed: the picture is shown clean, and
/// the bar says what the page is.
class ServiceGalleryAppBar extends StatefulWidget {
  const ServiceGalleryAppBar({
    required this.images,
    required this.title,
    this.onShare,
    super.key,
  });

  final List<ServiceMedia> images;

  /// Read by screen readers, so the page is still named for anyone not looking at it.
  final String title;

  /// Shown as an action only when a screen provides one.
  final VoidCallback? onShare;

  @override
  State<ServiceGalleryAppBar> createState() => _ServiceGalleryAppBarState();
}

class _ServiceGalleryAppBarState extends State<ServiceGalleryAppBar> {
  int _page = 0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screen = MediaQuery.sizeOf(context);

    // Sized from the screen rather than fixed at 260.
    //
    // A service is chosen on the strength of its photograph, and a fixed 260 gave it a letterbox
    // on every phone — too short to show the work, while the page underneath ran out of content
    // and left a band of empty white below the fold. Nine-tenths of the width is roughly a 10:9
    // frame, which suits the way people photograph a room or a finished job; the half-screen cap
    // keeps the price and the Book button in view on a short phone, which matters more than the
    // picture does.
    final galleryHeight = math.min(screen.width * 0.9, screen.height * 0.5);

    return SliverMainAxisGroup(
      slivers: [
        SliverAppBar(
          pinned: true,
          centerTitle: true,
          backgroundColor: theme.colorScheme.surface,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          leading: _RoundAction(
            icon: Icons.arrow_back_ios_new_rounded,
            label: 'Back',
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          title: Text(
            'Details',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          actions: [
            if (widget.onShare != null)
              _RoundAction(
                icon: Icons.ios_share_rounded,
                label: 'Share ${widget.title}',
                onPressed: widget.onShare!,
              ),
          ],
        ),
        SliverToBoxAdapter(
          child: SizedBox(
            height: galleryHeight,
            child: _Gallery(
              images: widget.images,
              page: _page,
              onPageChanged: (i) => setState(() => _page = i),
            ),
          ),
        ),
      ],
    );
  }
}

/// A bar button on a soft disc, so it reads as a control rather than a loose glyph.
class _RoundAction extends StatelessWidget {
  const _RoundAction({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: IconButton(
        onPressed: onPressed,
        tooltip: label,
        icon: Icon(icon, size: 18),
        style: IconButton.styleFrom(
          minimumSize: const Size(38, 38),
          backgroundColor: theme.colorScheme.surfaceContainerHighest,
          foregroundColor: theme.colorScheme.onSurface,
        ),
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
