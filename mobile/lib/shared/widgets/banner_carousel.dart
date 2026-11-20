import 'dart:async';

import 'package:flutter/material.dart';
import 'package:zuno/core/theme/app_colors.dart';
import 'package:zuno/shared/widgets/network_photo.dart';

/// One slide of a [BannerCarousel]: a photo with words on it and, optionally, a button.
class BannerSlide {
  const BannerSlide({
    required this.imageUrl,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.actionLabel,
  });

  /// The full address of the photo.
  final String? imageUrl;
  final String title;
  final String? subtitle;

  /// A small button on the slide, e.g. "Book"; null for none.
  final String? actionLabel;
  final VoidCallback onTap;
}

/// Featured items with photos at the top of a home, swiped sideways, with dots for where you are.
/// Nothing at all (a small gap) when there are no slides. Used by the Rent and Marketplace homes.
class BannerCarousel extends StatefulWidget {
  const BannerCarousel({
    required this.slides,
    this.height = 168,
    this.pagerKey,
    this.autoAdvance,
    this.postersOnly = false,
    super.key,
  });

  final List<BannerSlide> slides;
  final double height;

  /// The key of the sideways pager, for tests.
  final Key? pagerKey;

  /// Moves on to the next slide this often, round to the first after the last; null stays put.
  /// Not when the phone asks for less motion, and a swipe restarts the wait.
  final Duration? autoAdvance;

  /// The photo alone: a poster carries its own words, so no shade and no title over it.
  final bool postersOnly;

  @override
  State<BannerCarousel> createState() => _BannerCarouselState();
}

class _BannerCarouselState extends State<BannerCarousel> {
  final _pages = PageController(viewportFraction: 0.92);
  int _page = 0;
  Timer? _timer;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _restartTimer();
  }

  @override
  void didUpdateWidget(BannerCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.autoAdvance != widget.autoAdvance ||
        oldWidget.slides.length != widget.slides.length) {
      _restartTimer();
    }
  }

  void _restartTimer() {
    _timer?.cancel();
    _timer = null;
    final every = widget.autoAdvance;
    if (every == null ||
        widget.slides.length < 2 ||
        MediaQuery.disableAnimationsOf(context)) {
      return;
    }
    _timer = Timer.periodic(every, (_) {
      if (!_pages.hasClients) return;
      _pages.animateToPage(
        (_page + 1) % widget.slides.length,
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final slides = widget.slides;
    if (slides.isEmpty) return const SizedBox(height: 8);
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Column(
        children: [
          SizedBox(
            height: widget.height,
            child: PageView.builder(
              key: widget.pagerKey,
              controller: _pages,
              itemCount: slides.length,
              onPageChanged: (i) {
                setState(() => _page = i);
                _restartTimer();
              },
              itemBuilder: (context, index) => _Slide(
                slide: slides[index],
                theme: theme,
                posterOnly: widget.postersOnly,
              ),
            ),
          ),
          if (slides.length > 1) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < slides.length; i++)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: i == _page ? 18 : 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: i == _page
                          ? theme.colorScheme.primary
                          : theme.colorScheme.outlineVariant,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _Slide extends StatelessWidget {
  const _Slide({
    required this.slide,
    required this.theme,
    this.posterOnly = false,
  });

  final BannerSlide slide;
  final ThemeData theme;
  final bool posterOnly;

  @override
  Widget build(BuildContext context) {
    final action = slide.actionLabel;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Material(
          child: InkWell(
            onTap: slide.onTap,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Semantics(
                  label: slide.title,
                  image: true,
                  child: NetworkPhoto(url: slide.imageUrl),
                ),
                // Words on a photo need a shade under them to be read.
                if (!posterOnly) ...[
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          AppColors.mediaGradientFoot,
                        ],
                        stops: const [0.35, 1],
                      ),
                    ),
                  ),
                  Positioned(
                    left: 16,
                    right: 16,
                    bottom: 14,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                slide.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  color: AppColors.onMedia,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              if (slide.subtitle case final subtitle?)
                                Text(
                                  subtitle,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: AppColors.onMedia.withValues(
                                      alpha: 0.85,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        if (action != null) ...[
                          const SizedBox(width: 8),
                          FilledButton.tonal(
                            onPressed: slide.onTap,
                            style: FilledButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                            ),
                            child: Text(action),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
