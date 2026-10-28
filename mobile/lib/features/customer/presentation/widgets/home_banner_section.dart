import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:zuno/core/constants/api_constants.dart';
import 'package:zuno/core/utils/formatting.dart';
import 'package:zuno/features/customer/domain/entities/service_listing.dart';
import 'package:zuno/features/customer/presentation/providers/daily_banners_provider.dart';
import 'package:zuno/core/theme/app_colors.dart';

/// The banner strip on the customer's home screen: seven real services, swipeable.
///
/// It replaced a single painted card reading "Make your events special" over a dead "Explore now"
/// button — a promise with nothing behind it, going nowhere. Every banner here is a service somebody
/// has actually listed, with their own photograph, and tapping it opens that service.
///
/// The seven change daily, which the server decides. That matters more than it looks: a fixed banner
/// is a ranking, and the businesses that are not on it never get a turn.
class HomeBannerSection extends ConsumerStatefulWidget {
  const HomeBannerSection({super.key});

  @override
  ConsumerState<HomeBannerSection> createState() => _HomeBannerSectionState();
}

class _HomeBannerSectionState extends ConsumerState<HomeBannerSection> {
  final _controller = PageController(viewportFraction: 0.92);
  int _page = 0;

  /// Moves the banner on by itself, so all seven are seen rather than only the first.
  ///
  /// Five seconds: long enough to read a name and a price, short enough that somebody scrolling past
  /// sees more than one. Restarted whenever the page changes, including when the customer swipes it
  /// themselves — otherwise a banner they just chose could be snatched away a moment later.
  Timer? _timer;

  /// The banner count the running timer was started for, so a rebuild does not stack up timers.
  int? _runningFor;

  void _startAutoScroll(int count) {
    _timer?.cancel();
    _runningFor = count;

    // One banner has nowhere to go. And a page that moves on its own is exactly what somebody who
    // has asked for reduced motion is asking not to have.
    if (count < 2 || MediaQuery.maybeDisableAnimationsOf(context) == true) {
      _timer = null;
      return;
    }

    _timer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted || !_controller.hasClients) return;

      _controller.animateToPage(
        (_page + 1) % count,
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bannersAsync = ref.watch(dailyBannersProvider);

    return bannersAsync.when(
      // A thin placeholder of the same height, so the categories below do not jump up and then back
      // down as the banner arrives.
      loading: () => const SizedBox(height: 194),
      // Silent on failure. A banner is decoration; the feed underneath is the screen's job, and it
      // reports its own errors.
      error: (_, _) => const SizedBox.shrink(),
      data: (banners) {
        if (banners.isEmpty) return const SizedBox.shrink();

        // Started once per set of banners rather than on every build, or each rebuild would leave
        // another timer running and the strip would race through them.
        if (_runningFor != banners.length) {
          _startAutoScroll(banners.length);
        }

        return Column(
          children: [
            SizedBox(
              height: 178,
              child: PageView.builder(
                controller: _controller,
                itemCount: banners.length,
                onPageChanged: (i) {
                  setState(() => _page = i);
                  // Gives whichever banner is now showing its own full five seconds, whether it
                  // arrived by itself or because the customer swiped to it.
                  _startAutoScroll(banners.length);
                },
                itemBuilder: (context, index) => Padding(
                  padding: const EdgeInsets.fromLTRB(4, 8, 4, 4),
                  child: _BannerCard(service: banners[index]),
                ),
              ),
            ),
            if (banners.length > 1)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (var i = 0; i < banners.length; i++)
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        width: i == _page ? 16 : 6,
                        height: 6,
                        margin: const EdgeInsets.symmetric(horizontal: 2),
                        decoration: BoxDecoration(
                          color: i == _page
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(context).colorScheme.onSurfaceVariant
                                    .withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}

/// One banner: the service's own photograph, with just enough over it to decide.
class _BannerCard extends StatelessWidget {
  const _BannerCard({required this.service});

  final ServiceListing service;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final imageUrl = service.imageUrl;

    return InkWell(
      // related=0: a banner advertises one service, and a list of alternatives under it reads as a
      // change of subject rather than help.
      onTap: () => context.push('/customer/service/${service.id}?related=0'),
      borderRadius: BorderRadius.circular(16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (imageUrl != null)
              CachedNetworkImage(
                imageUrl: '${ApiConstants.baseUrl}$imageUrl',
                fit: BoxFit.cover,
                errorWidget: (_, _, _) =>
                    Container(color: theme.colorScheme.primaryContainer),
              )
            else
              Container(color: theme.colorScheme.primaryContainer),

            // Dark at the bottom only, so the photograph is still the thing you see while the words
            // stay readable over whatever happens to be behind them.
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, AppColors.mediaGradientFoot],
                  stops: [0.35, 1],
                ),
              ),
            ),

            Positioned(
              left: 14,
              right: 14,
              bottom: 12,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    service.serviceCategoryName.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: AppColors.onMedia.withValues(alpha: 0.85),
                      letterSpacing: 0.8,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    service.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: AppColors.onMedia,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          service.businessName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppColors.onMedia.withValues(alpha: 0.9),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        priceLabel(service.price, service.priceType),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: AppColors.onMedia,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
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
