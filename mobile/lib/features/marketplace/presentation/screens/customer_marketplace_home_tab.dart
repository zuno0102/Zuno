import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zuno/core/ui_config/ui_icons.dart';
import 'package:zuno/core/utils/formatting.dart';
import 'package:zuno/features/auth/presentation/providers/auth_notifier.dart';
import 'package:zuno/features/auth/presentation/providers/auth_state.dart';
import 'package:zuno/features/customer/presentation/providers/customer_home_location_provider.dart';
import 'package:zuno/features/customer/presentation/screens/customer_home_header.dart';
import 'package:zuno/features/marketplace/domain/entities/marketplace_customer.dart';
import 'package:zuno/features/marketplace/domain/entities/marketplace_post.dart';
import 'package:zuno/features/marketplace/presentation/providers/marketplace_customer_providers.dart';
import 'package:zuno/features/marketplace/presentation/providers/marketplace_providers.dart';
import 'package:zuno/features/marketplace/presentation/widgets/marketplace_post_card.dart';
import 'package:zuno/shared/widgets/banner_carousel.dart';
import 'package:zuno/shared/widgets/empty_state.dart';
import 'package:zuno/shared/widgets/error_banner.dart';
import 'package:zuno/shared/widgets/category_grid.dart';
import 'package:zuno/shared/widgets/section_header.dart';

/// The customer's Marketplace home, built like the Rent home: who and where, search and
/// categories, then the sections the server lists in order — product grids, poster banners that
/// move by themselves, B2B lots, food near them, headed rows (recommended, wishlist, discounts,
/// best sellers…) — and last every product, loaded as the customer scrolls. Food and adverts are
/// kept to the customer's district; products ship, so they show from everywhere.
class CustomerMarketplaceHomeTab extends ConsumerStatefulWidget {
  const CustomerMarketplaceHomeTab({this.notificationBell, super.key});

  /// The bell, built by the shell — the same notifications as the Service side.
  final Widget? notificationBell;

  @override
  ConsumerState<CustomerMarketplaceHomeTab> createState() =>
      _CustomerMarketplaceHomeTabState();
}

class _CustomerMarketplaceHomeTabState
    extends ConsumerState<CustomerMarketplaceHomeTab> {
  final _search = TextEditingController();
  String? _keyword;
  String? _categoryId;

  bool get _searching => _keyword != null || _categoryId != null;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _dismissKeyboard() => FocusScope.of(context).unfocus();

  void _clear() {
    _search.clear();
    setState(() {
      _keyword = null;
      _categoryId = null;
    });
  }

  Future<void> _refresh() async {
    ref
      ..invalidate(marketplaceHomeProvider)
      ..invalidate(marketplaceSearchProvider)
      ..invalidate(marketplaceFeedProvider);
    await ref.read(marketplaceHomeProvider.future);
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider).value;
    final categories =
        ref.watch(marketplaceCategoriesProvider).value ??
        const <MarketplaceCategory>[];

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: _dismissKeyboard,
      child: RefreshIndicator(
        onRefresh: _refresh,
        child: CustomScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          slivers: [
            SliverToBoxAdapter(
              child: CustomerHomeHeader(
                user: auth is AuthAuthenticated ? auth.user : null,
                location: ref
                    .watch(customerHomeLocationProvider)
                    .district
                    ?.name,
                trailing: widget.notificationBell,
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: TextField(
                  key: const ValueKey('marketplace-search'),
                  controller: _search,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (value) {
                    _dismissKeyboard();
                    final words = value.trim();
                    setState(() => _keyword = words.isEmpty ? null : words);
                  },
                  decoration: const InputDecoration(
                    hintText: 'Search sarees, bananas, biryani…',
                    prefixIcon: Icon(Icons.search),
                    isDense: true,
                  ),
                ),
              ),
            ),
            // The same category squares as the Service and Rent homes; tapping the chosen one again
            // clears it.
            if (categories.isNotEmpty)
              SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SectionHeader(title: 'Categories'),
                    CategoryGrid(
                      key: const ValueKey('marketplace-categories'),
                      selectedId: _categoryId,
                      onSelected: (id) {
                        _dismissKeyboard();
                        setState(() => _categoryId = id);
                      },
                      categories: [
                        for (final c in categories)
                          CategoryTile(
                            id: c.id,
                            label: c.shortName,
                            icon:
                                UiIcons.byName(c.iconName) ??
                                CategoryGrid.iconForCategory(
                                  iconName: c.iconName,
                                  name: c.name,
                                ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            if (_searching) ..._results() else ..._home(),
            const SliverToBoxAdapter(child: SizedBox(height: 32)),
          ],
        ),
      ),
    );
  }

  List<Widget> _results() {
    final results = ref.watch(
      marketplaceSearchProvider((keyword: _keyword, categoryId: _categoryId)),
    );
    return [
      SliverToBoxAdapter(
        child: SectionHeader(
          title: 'Matching',
          count: results.value?.totalCount,
          actionLabel: 'Clear',
          onAction: _clear,
        ),
      ),
      ...results.when(
        loading: () => [_loading()],
        error: (error, _) => [_error(error)],
        data: (page) => page.items.isEmpty
            ? const [
                SliverToBoxAdapter(
                  child: EmptyState(
                    icon: Icons.search_off,
                    title: 'Nothing matches',
                    message: 'Try other words or another category.',
                  ),
                ),
              ]
            : [_grid(page.items, key: const ValueKey('marketplace-results'))],
      ),
    ];
  }

  List<Widget> _home() => ref
      .watch(marketplaceHomeProvider)
      .when(
        loading: () => [_loading()],
        error: (error, _) => [_error(error)],
        data: (home) => home.isEmpty
            ? const [
                SliverToBoxAdapter(
                  child: EmptyState(
                    icon: Icons.storefront_outlined,
                    title: 'Nothing here yet',
                    message:
                        'Businesses near you have not put anything up yet. Check back soon.',
                  ),
                ),
              ]
            : [for (final section in home.sections) ..._section(section)],
      );

  /// A section as its layout says; keys are `marketplace-<code>` for tests.
  List<Widget> _section(MarketplaceHomeSection section) {
    final key = ValueKey('marketplace-${section.code}');
    final header = section.title.isEmpty
        ? null
        : SliverToBoxAdapter(child: SectionHeader(title: section.title));
    return switch (section.layout) {
      MarketplaceHomeLayout.banner => [
        SliverToBoxAdapter(
          child: _Banners(key: key, cards: section.items),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 6)),
      ],
      MarketplaceHomeLayout.grid => [?header, _grid(section.items, key: key)],
      MarketplaceHomeLayout.strip => [?header, _strip(section.items, key)],
      MarketplaceHomeLayout.feed => _feed(section, header, key),
    };
  }

  /// Everything, a page at a time: the next loads as the customer nears the foot.
  List<Widget> _feed(MarketplaceHomeSection section, Widget? header, Key key) {
    final feed = ref.watch(marketplaceFeedProvider(section.pageSize));
    final page = feed.value;
    if (page == null || page.items.isEmpty) {
      return [if (feed.isLoading) _loading()];
    }
    final notifier = ref.read(
      marketplaceFeedProvider(section.pageSize).notifier,
    );
    return [
      ?header,
      _grid(
        page.items,
        key: key,
        // Drawing the last few cards asks for the next page — whether the customer scrolled
        // there or the page was short enough to show them at once.
        onNearEnd: page.hasMore && !page.loadFailed
            ? () => WidgetsBinding.instance.addPostFrameCallback(
                (_) => notifier.loadMore(),
              )
            : null,
      ),
      if (page.isLoadingMore) _loading(),
      if (page.loadFailed)
        SliverToBoxAdapter(
          child: Center(
            child: TextButton.icon(
              key: const ValueKey('marketplace-feed-retry'),
              onPressed: notifier.loadMore,
              icon: const Icon(Icons.refresh),
              label: const Text('Try again'),
            ),
          ),
        ),
    ];
  }

  Widget _loading() => const SliverToBoxAdapter(
    child: Padding(
      padding: EdgeInsets.all(40),
      child: Center(child: CircularProgressIndicator()),
    ),
  );

  Widget _error(Object error) => SliverToBoxAdapter(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: ErrorBanner(message: error.toString()),
    ),
  );

  /// A sideways strip, as on the Rent home.
  Widget _strip(List<MarketplaceCard> cards, Key key) => SliverToBoxAdapter(
    child: SizedBox(
      height: 236,
      child: ListView.separated(
        key: key,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: cards.length,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (context, index) => SizedBox(
          width: 168,
          child: MarketplacePostCard(card: cards[index]),
        ),
      ),
    ),
  );

  /// Two across, always — as on the Rent and Service homes. [onNearEnd] is called as one of the
  /// last row or two is drawn.
  Widget _grid(
    List<MarketplaceCard> cards, {
    Key? key,
    VoidCallback? onNearEnd,
  }) => SliverPadding(
    key: key,
    padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
    sliver: SliverGrid.builder(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.72,
      ),
      itemCount: cards.length,
      itemBuilder: (context, index) {
        if (index >= cards.length - 4) onNearEnd?.call();
        return MarketplacePostCard(card: cards[index]);
      },
    ),
  );
}

/// The advert posters, framed 3 : 1 as businesses crop them, moving on every few seconds.
class _Banners extends StatelessWidget {
  const _Banners({required this.cards, super.key});

  /// How long each poster stays before the next slides in.
  static const autoAdvance = Duration(seconds: 4);

  final List<MarketplaceCard> cards;

  @override
  Widget build(BuildContext context) {
    // The pager shows 92% of the width; the banner keeps its 3 : 1 inside it.
    final height = MediaQuery.sizeOf(context).width * 0.92 / 3;
    return BannerCarousel(
      pagerKey: const ValueKey('marketplace-banners-pager'),
      height: height,
      autoAdvance: autoAdvance,
      postersOnly: true,
      slides: [
        for (final card in cards)
          BannerSlide(
            imageUrl: marketplacePhotoUrl(card.imageUrl),
            title: card.title,
            subtitle: [
              card.businessName,
              if (card.endsAt case final ends?) 'till ${formatDayMonth(ends)}',
            ].join(' · '),
            onTap: () => openMarketplacePost(context, card),
          ),
      ],
    );
  }
}
