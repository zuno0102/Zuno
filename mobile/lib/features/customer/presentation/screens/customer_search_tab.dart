import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:zuno/features/catalog/presentation/providers/catalog_providers.dart';
import 'package:zuno/features/auth/presentation/providers/auth_notifier.dart';
import 'package:zuno/features/auth/presentation/providers/auth_state.dart';
import 'package:zuno/features/customer/presentation/providers/customer_search_filter_provider.dart';
import 'package:zuno/features/customer/presentation/providers/daily_banners_provider.dart';
import 'package:zuno/features/customer/presentation/providers/service_search_notifier.dart';
import 'package:zuno/features/customer/presentation/screens/customer_home_header.dart';
import 'package:zuno/features/customer/presentation/widgets/home_banner_section.dart';
import 'package:zuno/features/customer/presentation/widgets/home_sections_view.dart';
import 'package:zuno/features/customer/presentation/widgets/service_card.dart';

import 'package:zuno/shared/widgets/category_grid.dart';
import 'package:zuno/shared/widgets/empty_state.dart';
import 'package:zuno/shared/widgets/error_banner.dart';
import 'package:zuno/shared/widgets/section_header.dart';
import 'package:zuno/shared/widgets/multi_select_sheet.dart';

class CustomerSearchTab extends ConsumerStatefulWidget {
  const CustomerSearchTab({this.notificationBell, super.key});

  /// The bell, built by the shell.
  ///
  /// Handed down rather than built here because it needs to know where each notification leads,
  /// and only the shell knows its own tabs and screens.
  final Widget? notificationBell;

  @override
  ConsumerState<CustomerSearchTab> createState() => _CustomerSearchTabState();
}

class _CustomerSearchTabState extends ConsumerState<CustomerSearchTab> {
  /// Only the text box lives here, and it is refilled from the filter on every build.
  ///
  /// Everything else a customer chooses — their district, the category, the words they searched for —
  /// is held by [customerSearchFilterProvider] instead. This screen is disposed the moment they open
  /// another tab, so anything kept in widget state is lost on the way to Bookings and back.
  final _searchController = TextEditingController();

  /// Drives the back-to-top button, and the scroll it performs.
  final _scrollController = ScrollController();

  /// Whether the customer is far enough down to want a way back.
  bool _showBackToTop = false;

  /// About two screens. Low enough to be there when somebody wants it, high enough that it does not
  /// appear over the categories the moment the page moves.
  static const _backToTopAfter = 900.0;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;

    final shouldShow = _scrollController.offset > _backToTopAfter;

    // Only when it actually changes: this fires on every frame of a scroll, and rebuilding a page
    // of forty cards sixty times a second would cost more than the button is worth.
    if (shouldShow != _showBackToTop) {
      setState(() => _showBackToTop = shouldShow);
    }
  }

  Future<void> _backToTop() async {
    _dismissKeyboard();

    await _scrollController.animateTo(
      0,
      // Long enough to read as travel rather than a jump, short enough not to be a wait. The whole
      // page is six sections deep, so landing instantly leaves somebody unsure where they are.
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  CustomerSearchFilterNotifier get _filter =>
      ref.read(customerSearchFilterProvider.notifier);

  /// Closes the keyboard and takes the cursor out of the search box.
  ///
  /// Called by everything else on this screen. Tapping a category or the location button left the
  /// field focused and the keyboard up, covering half the results the tap had just changed — so the
  /// customer had to dismiss it by hand before they could see what they had done.
  void _dismissKeyboard() => FocusScope.of(context).unfocus();

  void _runSearch() {
    _dismissKeyboard();
    _filter.setKeyword(_searchController.text);
  }

  void _selectCategory(String? categoryId) {
    _dismissKeyboard();
    _filter.toggleCategory(categoryId);
  }

  Future<void> _pickLocation() async {
    _dismissKeyboard();
    final current = ref.read(customerSearchFilterProvider);
    final states = await ref.read(locationStatesProvider.future);
    if (!mounted) return;

    final states0 = await showMultiSelectSheet(
      context: context,
      title: 'States',
      options: states
          .map((s) => MultiSelectOption(id: s.id, label: s.name))
          .toList(),
      initialSelectedIds: current.stateIds,
      // The way out. Clearing the filter otherwise meant unticking every state by hand, and a
      // customer who had picked four had to remember which four.
      clearLabel: 'Clear location',
    );
    if (states0 == null) return;

    if (states0.isEmpty) {
      _filter.clearLocation();
      return;
    }

    final stateIdsCsv = (states0.toList()..sort()).join(',');
    final districts = await ref.read(
      districtsForStatesProvider(stateIdsCsv).future,
    );
    if (!mounted) return;

    final districtIds = await showMultiSelectSheet(
      context: context,
      title: 'Districts',
      options: districts
          .map(
            (d) => MultiSelectOption(
              id: d.id,
              label: '${d.name} (${d.stateName})',
            ),
          )
          .toList(),
      initialSelectedIds: current.districtIds
          .where((id) => districts.any((d) => d.id == id))
          .toSet(),
      // Offered here too, so somebody two sheets deep does not have to back out to find it.
      clearLabel: 'Clear location',
    );
    if (districtIds == null) return;

    if (districtIds.isEmpty) {
      // No districts means no location filter, whichever states are ticked behind it. Said plainly
      // rather than stored as "these states, no districts", which would read as a filter that
      // matches nothing.
      _filter.clearLocation();
      return;
    }

    _filter.setLocation(
      stateIds: states0,
      districtIds: districtIds,
      // The first one they ticked, named. The sheet hands the ids back in the order they were
      // chosen, so this is their own first choice rather than whichever sorts first.
      primaryDistrictName: districtIds.isEmpty
          ? null
          : districts
                .where((d) => d.id == districtIds.first)
                .map((d) => d.name)
                .firstOrNull,
    );
  }

  @override
  Widget build(BuildContext context) {
    final servicesAsync = ref.watch(serviceSearchProvider);
    final categoriesAsync = ref.watch(serviceCategoriesProvider);
    final authValue = ref.watch(authProvider).value;
    final user = authValue is AuthAuthenticated ? authValue.user : null;
    final filter = ref.watch(customerSearchFilterProvider);

    // Refilled from the filter, because this screen is rebuilt from scratch every time the customer
    // comes back from another tab and the box would otherwise be empty under filtered results.
    if (_searchController.text != filter.keyword) {
      _searchController.text = filter.keyword;
      _searchController.selection = TextSelection.collapsed(
        offset: filter.keyword.length,
      );
    }

    return GestureDetector(
      // Tapping anywhere that is not a control puts the keyboard away. Translucent so the tap still
      // reaches whatever is underneath — this closes the keyboard, it does not swallow the gesture.
      behavior: HitTestBehavior.translucent,
      onTap: _dismissKeyboard,
      child: Stack(
        children: [
          _buildScrollView(context, filter, servicesAsync, categoriesAsync, user),
          // Sits above the list rather than in the shell's Scaffold: the button belongs to this
          // page, and a floating action button on the shell would follow the customer onto
          // Bookings and Chat where there is nothing to scroll back from.
          Positioned(
            right: 16,
            bottom: 20,
            child: _BackToTopButton(
              visible: _showBackToTop,
              onPressed: _backToTop,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScrollView(
    BuildContext context,
    CustomerSearchFilter filter,
    AsyncValue<List<dynamic>> servicesAsync,
    AsyncValue<dynamic> categoriesAsync,
    dynamic user,
  ) {
    return RefreshIndicator(
        // Refetches the same question. Changing the filter is what asks a new one.
        // A pull down asks for something else to look at, so the home sections come back in a new
        // order with a different spread of services. Re-rolling the seed does that; the sections
        // provider watches it and refetches on its own.
        //
        // The filtered results are simply refetched: under a search, "show me something else" is not
        // what a pull means.
        onRefresh: () async {
          ref.read(homeShuffleSeedProvider.notifier).reroll();
          await ref.read(serviceSearchProvider.notifier).refresh();
        },
        child: CustomScrollView(
          controller: _scrollController,
          // Scrolling the results is as clear a sign as any that somebody has finished typing.
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          slivers: [
            // 1. Who is signed in, and where results are drawn from.
            SliverToBoxAdapter(
              child: CustomerHomeHeader(
                user: user,
                location: locationSummary(
                  primaryName: filter.primaryDistrictName,
                  districtCount: filter.districtIds.length,
                ),
                trailing: widget.notificationBell,
              ),
            ),

            // 2. Search, with the location filter beside it rather than stacked — they are two
            // halves of the same question, and stacking pushed results below the fold.
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        textInputAction: TextInputAction.search,
                        onSubmitted: (_) => _runSearch(),
                        decoration: const InputDecoration(
                          hintText: 'Search services, events, or businesses',
                          prefixIcon: Icon(Icons.search),
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _LocationButton(
                      count: filter.districtIds.length,
                      onPressed: _pickLocation,
                    ),
                  ],
                ),
              ),
            ),

            // 3. The banner strip: seven real services, a different seven tomorrow.
            const SliverToBoxAdapter(child: HomeBannerSection()),

            // 4. Categories.
            SliverToBoxAdapter(
              child: categoriesAsync.when(
                loading: () => const SizedBox(height: 120),
                error: (_, _) => const SizedBox.shrink(),
                data: (categories) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SectionHeader(title: 'What do you need?'),
                    CategoryGrid(
                      selectedId: filter.categoryId,
                      onSelected: _selectCategory,
                      categories: [
                        for (final c in categories)
                          CategoryTile(
                            id: c.id,
                            label: c.name,
                            iconUrl: c.iconUrl,
                            icon: CategoryGrid.iconForCategory(
                              iconName: c.iconName,
                              name: c.name,
                            ),
                          ),
                      ],
                      onMore: () => _showAllCategories(categories),
                    ),
                  ],
                ),
              ),
            ),

            // 5. What was asked for, first and under its own name.
            //
            // A band at the top rather than a page that replaces itself: the filter answers "show me
            // catering in Kanyakumari", and the home screen below still answers "what else is here".
            // Replacing the whole page meant a district — which the app now remembers between
            // launches — cost the customer their home screen permanently.
            if (filter.isFiltering) ...[
              SliverToBoxAdapter(
                child: SectionHeader(
                  title: matchingSectionTitle(
                    hasLocation: filter.hasLocation,
                    hasSearchTerms: filter.hasSearchTerms,
                  ),
                  count: servicesAsync.value?.length,
                  // Only for what a customer typed or tapped just now. The district is where they
                  // live, cleared from inside the location picker — not by a button that happens to
                  // sit beside today's search results.
                  actionLabel: filter.hasSearchTerms ? 'Clear' : null,
                  onAction: filter.hasSearchTerms ? _clearFilters : null,
                ),
              ),
              servicesAsync.when(
                loading: () => const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(40),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                ),
                error: (error, _) => SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: ErrorBanner(message: error.toString()),
                  ),
                ),
                data: (services) {
                  if (services.isEmpty) {
                    return SliverToBoxAdapter(
                      child: EmptyState(
                        icon: Icons.search_off,
                        title: 'Nothing here yet',
                        message: filter.hasSearchTerms
                            ? 'No service matches these filters. Try widening them.'
                            : 'Nothing is listed near your location yet. '
                                  'Everything else is below.',
                        // Whichever of the two is actually in the way. With only a district set,
                        // "Clear filters" would clear nothing and look broken.
                        actionLabel: filter.hasSearchTerms
                            ? 'Clear filters'
                            : 'Search everywhere',
                        onAction: filter.hasSearchTerms
                            ? _clearFilters
                            : () {
                                _dismissKeyboard();
                                _filter.clearLocation();
                              },
                      ),
                    );
                  }

                  // Two across, always: a service is judged on its picture, and a full-width row
                  // would show half as many for no extra information. Fixed at two rather than
                  // fitted to the width, so the grid is the same shape on every phone and twenty
                  // services are ten rows wherever they are read.
                  return SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
                    sliver: SliverGrid.builder(
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            mainAxisSpacing: 12,
                            crossAxisSpacing: 12,
                            childAspectRatio: 0.74,
                          ),
                      itemCount: services.length,
                      itemBuilder: (context, index) {
                        final service = services[index];
                        return ServiceCard(
                          service: service,
                          onTap: () =>
                              context.push('/customer/service/${service.id}'),
                        );
                      },
                    ),
                  );
                },
              ),
            ],

            // 6. The home screen itself, under every filter and none.
            //
            // Unnarrowed on purpose. These sections are the catalogue — what Zuno has — and a
            // district with four businesses in it would otherwise leave the customer with four
            // cards and nothing to browse.
            ...ref
                .watch(homeSectionsProvider)
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
                      ? const [
                          SliverToBoxAdapter(
                            child: EmptyState(
                              icon: Icons.storefront_outlined,
                              title: 'Nothing listed yet',
                              message:
                                  'No businesses have listed a service for your area yet.',
                            ),
                          ),
                        ]
                      : homeSectionSlivers(context, sections),
                ),
          ],
        ),
    );
  }


  /// The categories that did not fit in the grid.
  ///
  /// Its own sheet, not the app's generic multi-select one: that is the checkbox-and-search sheet the
  /// district filter opens, so tapping More on the categories produced something a customer read as
  /// the location picker. It was also multi-select over a filter that only ever takes one category —
  /// three ticks went in and only the first came out.
  Future<void> _showAllCategories(List<dynamic> categories) async {
    _dismissKeyboard();
    final picked = await showAllCategoriesSheet(
      context,
      categories: [
        for (final c in categories)
          CategoryTile(
            id: c.id as String,
            label: c.name as String,
            iconUrl: c.iconUrl as String?,
            icon: CategoryGrid.iconForCategory(
              iconName: c.iconName as String?,
              name: c.name as String,
            ),
          ),
      ],
      selectedId: ref.read(customerSearchFilterProvider).categoryId,
    );
    if (picked == null) return;
    // Set, not toggled: picking a category from a list that already shows it ticked means "this
    // one", never "turn it off". The grid is where tapping the chosen tile clears it.
    _filter.setCategory(picked.id);
  }

  /// Clears the category and the words typed. Not the district.
  ///
  /// The district is where the customer lives, kept between launches — so this Clear, which sits
  /// beside the results, would otherwise be a one-tap way to lose a standing preference they set
  /// once. Clearing the location is offered inside the location picker, where somebody goes when
  /// changing where they are looking is what they actually mean.
  void _clearFilters() {
    _searchController.clear();
    _filter.clearSearch();
  }
}

/// A compact location filter that says how many districts are chosen.
class _LocationButton extends StatelessWidget {
  const _LocationButton({required this.count, required this.onPressed});

  final int count;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final active = count > 0;

    return Material(
      color: active
          ? theme.colorScheme.primaryContainer
          : theme.colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          child: Row(
            children: [
              Icon(
                Icons.place_outlined,
                size: 19,
                color: active ? theme.colorScheme.primary : null,
              ),
              if (active) ...[
                const SizedBox(width: 4),
                Text(
                  '$count',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// What to call the band of matching services at the top of the home screen.
///
/// Three headings, and none of them repeats a choice back at the customer:
///
///   * `Services near you` — a district set
///   * `Matching services` — a category or typed words
///   * `Matching services near you` — both
///
/// Deliberately generic. Spelling the choice out — "Painting services in Kanyakumari" — reads as the
/// app reciting what was just tapped, and the district already sits under the greeting with a pin
/// beside it while the category is lit in the grid above. The heading's job is to say what this band
/// of cards *is*, which does not change with the words in it.
String matchingSectionTitle({
  required bool hasLocation,
  required bool hasSearchTerms,
}) {
  final subject = hasSearchTerms ? 'Matching services' : 'Services';
  return hasLocation ? '$subject near you' : subject;
}

/// What the line under the greeting says about where results are drawn from.
///
/// The place, not a tally. It used to read "4 district(s)", which tells a customer how many places
/// they picked — something they already know — and names none of them. This names their first choice
/// and counts the rest, so the line stays one line however many they pick, and the search still runs
/// on every district behind it.
///
/// Null means everywhere, which the header renders in its own words.
String? locationSummary({
  required String? primaryName,
  required int districtCount,
}) {
  if (districtCount <= 0) return null;

  // Falls back to the count only when the name could not be resolved — better than an empty line.
  final primary =
      primaryName ??
      '$districtCount ${districtCount == 1 ? 'district' : 'districts'}';
  final rest = districtCount - 1;

  return rest > 0 ? '$primary +$rest' : primary;
}

/// A small button that takes the customer back to the top of a long page.
///
/// The home screen is six sections and roughly forty cards deep, so somebody who scrolled to the
/// bottom had a long way back — and no gesture on Android does it for them, unlike the status-bar tap
/// on iOS.
///
/// Appears and leaves rather than sitting there permanently: on the first screen there is nothing to
/// return from, and a control that can never do anything is worse than no control.
class _BackToTopButton extends StatelessWidget {
  const _BackToTopButton({required this.visible, required this.onPressed});

  final bool visible;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return IgnorePointer(
      // Not just invisible: a faded-out button still catches taps, and an invisible thing taking a
      // tap meant for a card underneath it is the worst kind of bug to report.
      ignoring: !visible,
      child: AnimatedOpacity(
        opacity: visible ? 1 : 0,
        duration: const Duration(milliseconds: 180),
        child: AnimatedScale(
          // Grows in rather than fading alone, which reads as the button arriving rather than the
          // page having been foggy.
          scale: visible ? 1 : 0.7,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutBack,
          child: Material(
            color: theme.colorScheme.primary,
            shape: const CircleBorder(),
            elevation: 3,
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onPressed,
              child: Padding(
                padding: const EdgeInsets.all(11),
                child: Icon(
                  Icons.keyboard_arrow_up_rounded,
                  size: 24,
                  color: theme.colorScheme.onPrimary,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
