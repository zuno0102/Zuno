import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zuno/core/router/push_screen.dart';
import 'package:zuno/core/utils/formatting.dart';
import 'package:zuno/features/auth/presentation/providers/auth_notifier.dart';
import 'package:zuno/features/auth/presentation/providers/auth_state.dart';
import 'package:zuno/features/customer/presentation/providers/customer_home_location_provider.dart';
import 'package:zuno/features/customer/presentation/providers/customer_search_filter_provider.dart';
import 'package:zuno/features/customer/presentation/screens/customer_home_header.dart';
import 'package:zuno/features/customer/presentation/widgets/customer_location_picker.dart';
import 'package:zuno/features/rental/domain/entities/rental_customer.dart';
import 'package:zuno/features/rental/domain/entities/rental_item.dart';
import 'package:zuno/features/rental/presentation/providers/rental_customer_providers.dart';
import 'package:zuno/features/rental/presentation/providers/rental_providers.dart';
import 'package:zuno/features/rental/presentation/screens/rental_item_screen.dart';
import 'package:zuno/features/rental/presentation/widgets/rental_item_card.dart';
import 'package:zuno/shared/widgets/banner_carousel.dart';
import 'package:zuno/shared/widgets/category_grid.dart';
import 'package:zuno/shared/widgets/empty_state.dart';
import 'package:zuno/shared/widgets/error_banner.dart';
import 'package:zuno/shared/widgets/section_header.dart';

/// The customer's Rent home, built like the Service home: who and where, search, featured items,
/// categories, then sections of rent items — a sideways strip, a grid, a strip, a grid — in a shuffle
/// that changes with every pull to refresh. Location, header, bell and pickers are the Service
/// home's own.
class RentalHomeTab extends ConsumerStatefulWidget {
  const RentalHomeTab({this.notificationBell, super.key});

  /// The bell, built by the shell — the same notifications as the Service side.
  final Widget? notificationBell;

  @override
  ConsumerState<RentalHomeTab> createState() => _RentalHomeTabState();
}

class _RentalHomeTabState extends ConsumerState<RentalHomeTab> {
  final _search = TextEditingController();
  final _scroll = ScrollController();
  bool _showBackToTop = false;

  /// About two screens, as on the Service home.
  static const _backToTopAfter = 900.0;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      final show = _scroll.hasClients && _scroll.offset > _backToTopAfter;
      if (show != _showBackToTop) setState(() => _showBackToTop = show);
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    _search.dispose();
    super.dispose();
  }

  void _dismissKeyboard() => FocusScope.of(context).unfocus();

  void _open(RentalCard card) {
    _dismissKeyboard();
    pushScreen(context, RentalItemScreen(itemId: card.id, preview: card));
  }

  Future<void> _refresh() async {
    // A pull asks for something else to look at: a new shuffle, and the search asked again.
    ref.read(rentalHomeSeedProvider.notifier).reroll();
    ref
      ..invalidate(rentalBannersProvider)
      ..invalidate(rentalRecommendedProvider)
      ..invalidate(rentalSearchProvider);
    await ref.read(rentalHomeProvider.future);
  }

  Future<void> _showAllCategories(List<RentalCategory> categories) async {
    _dismissKeyboard();
    final picked = await showAllCategoriesSheet(
      context,
      categories: _tiles(categories),
      selectedId: ref.read(rentalBrowseProvider).categoryId,
    );
    if (picked == null) return;
    ref.read(rentalBrowseProvider.notifier).setCategory(picked.id);
  }

  static List<CategoryTile> _tiles(List<RentalCategory> categories) => [
    for (final c in categories)
      CategoryTile(
        id: c.id,
        label: c.name,
        icon: CategoryGrid.iconForCategory(iconName: c.iconName, name: c.name),
      ),
  ];

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider).value;
    final location = ref.watch(customerSearchFilterProvider);
    final browse = ref.watch(rentalBrowseProvider);

    // Refilled from the filter: this tab is rebuilt whenever the customer comes back to it.
    if (_search.text != browse.keyword) {
      _search.text = browse.keyword;
      _search.selection = TextSelection.collapsed(
        offset: browse.keyword.length,
      );
    }

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: _dismissKeyboard,
      child: Stack(
        children: [
          RefreshIndicator(
            onRefresh: _refresh,
            child: CustomScrollView(
              controller: _scroll,
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              slivers: [
                // 1. Who is signed in, and where — the app's one location, shared with Service.
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

                // 2. Search, with the same location button beside it.
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            key: const ValueKey('rent-search'),
                            controller: _search,
                            textInputAction: TextInputAction.search,
                            onSubmitted: (value) {
                              _dismissKeyboard();
                              ref
                                  .read(rentalBrowseProvider.notifier)
                                  .setKeyword(value);
                            },
                            decoration: const InputDecoration(
                              hintText: 'Search chairs, tents, tools…',
                              prefixIcon: Icon(Icons.search),
                              isDense: true,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        CustomerLocationButton(
                          count: location.districtIds.length,
                          onPressed: () {
                            _dismissKeyboard();
                            pickCustomerLocation(context, ref);
                          },
                        ),
                      ],
                    ),
                  ),
                ),

                // 3. Featured: a few items with photos, the same all day.
                const SliverToBoxAdapter(child: _RentBanners()),

                // 4. Categories, from the Rent server's table.
                SliverToBoxAdapter(
                  child: ref
                      .watch(rentalCategoriesProvider)
                      .when(
                        loading: () => const SizedBox(height: 120),
                        error: (_, _) => const SizedBox.shrink(),
                        data: (categories) => Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SectionHeader(title: 'Popular categories'),
                            CategoryGrid(
                              selectedId: browse.categoryId,
                              onSelected: (id) {
                                _dismissKeyboard();
                                ref
                                    .read(rentalBrowseProvider.notifier)
                                    .toggleCategory(id);
                              },
                              categories: _tiles(categories),
                              onMore: () => _showAllCategories(categories),
                            ),
                          ],
                        ),
                      ),
                ),

                // 5. Right under the categories: what can be rented in the customer's own district,
                // only when something can — as on the Service home. Not while searching.
                if (!browse.isSearching && !location.hasLocation)
                  ..._recommended(),

                // 6. What was asked for, above the home — the home below stays to browse.
                if (browse.isSearching || location.hasLocation)
                  ..._searchResults(browse),

                // 6. The home: strips and grids, as the server's section table lays them out.
                ...ref
                    .watch(rentalHomeProvider)
                    .when(
                      loading: () => const [
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: EdgeInsets.all(40),
                            child: Center(child: CircularProgressIndicator()),
                          ),
                        ),
                      ],
                      error: (error, _) => [
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: ErrorBanner(message: error.toString()),
                          ),
                        ),
                      ],
                      data: (sections) => sections.isEmpty
                          ? [
                              SliverToBoxAdapter(
                                child: EmptyState(
                                  icon: Icons.inventory_2_outlined,
                                  title: 'Nothing to rent here yet',
                                  message: location.hasLocation
                                      ? 'No rent items are offered in your area yet.'
                                      : 'No rent items are listed yet. Check back soon.',
                                  actionLabel: location.hasLocation
                                      ? 'Search everywhere'
                                      : null,
                                  onAction: location.hasLocation
                                      ? () => ref
                                            .read(
                                              customerSearchFilterProvider
                                                  .notifier,
                                            )
                                            .clearLocation()
                                      : null,
                                ),
                              ),
                            ]
                          : [
                              for (final section in sections)
                                ..._section(section),
                              const SliverToBoxAdapter(
                                child: SizedBox(height: 32),
                              ),
                            ],
                    ),
              ],
            ),
          ),
          Positioned(
            right: 16,
            bottom: 20,
            child: BackToTopButton(
              visible: _showBackToTop,
              onPressed: () => _scroll.animateTo(
                0,
                duration: const Duration(milliseconds: 420),
                curve: Curves.easeOutCubic,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// "Recommended rentals near you": what can be rented in the customer's own district, in one
  /// strip. Nothing at all while it loads or when the district has nothing listed — the page below
  /// is the same either way.
  List<Widget> _recommended() {
    final cards = ref.watch(rentalRecommendedProvider).value ?? const [];
    if (cards.isEmpty) return const [];
    return [
      SliverToBoxAdapter(child: SectionHeader(title: recommendedRentalsTitle)),
      SliverToBoxAdapter(
        child: SizedBox(
          height: 236,
          child: ListView.separated(
            key: const ValueKey('rent-recommended-strip'),
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: cards.length,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (context, index) => SizedBox(
              width: 168,
              child: RentalItemCard(
                card: cards[index],
                onTap: () => _open(cards[index]),
              ),
            ),
          ),
        ),
      ),
    ];
  }

  List<Widget> _searchResults(RentalBrowseFilter browse) => [
    SliverToBoxAdapter(
      child: SectionHeader(
        title: matchingRentalsTitle(
          hasLocation: ref.watch(customerSearchFilterProvider).hasLocation,
        ),
        count: ref.watch(rentalSearchProvider).value?.length,
        actionLabel: 'Clear',
        // The whole search, the district filter included — the customer's own location is kept
        // apart and is not touched.
        onAction: () {
          _search.clear();
          ref.read(rentalBrowseProvider.notifier).clear();
          if (ref.read(customerSearchFilterProvider).hasLocation) {
            ref.read(customerSearchFilterProvider.notifier).clearLocation();
          }
        },
      ),
    ),
    ...ref
        .watch(rentalSearchProvider)
        .when(
          loading: () => const [
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator()),
              ),
            ),
          ],
          error: (error, _) => [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: ErrorBanner(message: error.toString()),
              ),
            ),
          ],
          data: (cards) => cards.isEmpty
              ? const [
                  SliverToBoxAdapter(
                    child: EmptyState(
                      icon: Icons.search_off,
                      title: 'Nothing matches',
                      message:
                          'Try other words, another category, or a wider area.',
                    ),
                  ),
                ]
              : [_grid(cards)],
        ),
  ];

  /// One home section, laid out as the server says: a sideways strip or a two-column grid.
  List<Widget> _section(RentalHomeSection section) => [
    SliverToBoxAdapter(child: SectionHeader(title: section.title)),
    switch (section.layout) {
      RentalHomeLayout.strip => SliverToBoxAdapter(
        child: SizedBox(
          height: 236,
          child: ListView.separated(
            key: ValueKey('rent-strip-${section.code}'),
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: section.items.length,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (context, index) => SizedBox(
              width: 168,
              child: RentalItemCard(
                card: section.items[index],
                onTap: () => _open(section.items[index]),
              ),
            ),
          ),
        ),
      ),
      RentalHomeLayout.grid => _grid(
        section.items,
        key: ValueKey('rent-grid-${section.code}'),
      ),
    },
  ];

  /// Two across, always — as on the Service home, so a page reads the same on every phone.
  Widget _grid(List<RentalCard> cards, {Key? key}) => SliverPadding(
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
      itemBuilder: (context, index) =>
          RentalItemCard(card: cards[index], onTap: () => _open(cards[index])),
    ),
  );
}

/// A few featured rent items with photos — the shared [BannerCarousel], with Book on each.
class _RentBanners extends ConsumerWidget {
  const _RentBanners();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cards =
        ref.watch(rentalBannersProvider).value ?? const <RentalCard>[];
    void open(RentalCard card) =>
        pushScreen(context, RentalItemScreen(itemId: card.id, preview: card));
    return BannerCarousel(
      pagerKey: const ValueKey('rent-banners'),
      slides: [
        for (final card in cards)
          BannerSlide(
            imageUrl: rentalPhotoUrl(card.imageUrl),
            title: card.name,
            subtitle:
                '${rupees(card.price)}${card.unitSuffix}'
                '${card.districtName == null ? '' : ' · ${card.districtName}'}',
            actionLabel: 'Book',
            onTap: () => open(card),
          ),
      ],
    );
  }
}

/// The heading of the first section when a location is set and nothing is being searched.
const recommendedRentalsTitle = 'Recommended rentals near you';

/// The heading over search results — "near you" when a location narrows them, as on Service.
String matchingRentalsTitle({required bool hasLocation}) =>
    hasLocation ? 'Matching rentals near you' : 'Matching rentals';
