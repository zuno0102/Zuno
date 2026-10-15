import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'customer_search_filter_provider.g.dart';

/// What the customer has asked their home screen to show: where, what kind, and any words typed.
///
/// Held for the life of the app rather than the life of the screen. The customer shell builds one tab
/// at a time — `body: tabs[_index]`, not an IndexedStack — so opening Bookings **disposes** the search
/// tab. With the filter living in that widget's state, a customer who set their district, looked at
/// their bookings and came back found it gone, and the feed had quietly refetched every service in
/// the country.
///
/// The **location is kept on the device**; the category and the typed words are not. They are two
/// different kinds of thing. Where somebody lives is a standing fact — a customer in Kanyakumari is
/// still in Kanyakumari tomorrow, and making them re-pick their district on every launch is a toll
/// on the one filter that is true every time. What they searched for is a passing question, and
/// reopening the app under yesterday's category would be a filter nobody remembers setting.
class CustomerSearchFilter {
  const CustomerSearchFilter({
    this.categoryId,
    this.keyword = '',
    this.stateIds = const {},
    this.districtIds = const {},
    this.primaryDistrictName,
  });

  final String? categoryId;
  final String keyword;

  /// The states whose districts were offered, kept so reopening the picker starts where it left off.
  final Set<String> stateIds;

  final Set<String> districtIds;

  /// The name of the first district chosen, for the line under the greeting.
  final String? primaryDistrictName;

  bool get hasLocation => districtIds.isNotEmpty;

  /// Whether anything has been narrowed — which decides only whether the band of matching services
  /// appears above the home sections, never whether those sections appear at all.
  ///
  /// The home screen keeps its shape under every filter. A customer who sets their district still
  /// scrolls past "Services for you" and the rest below the matches; collapsing the page into a flat
  /// list would mean a saved district — kept between launches — permanently costing them the home
  /// screen they opened the app for.
  bool get isFiltering =>
      categoryId != null || keyword.isNotEmpty || districtIds.isNotEmpty;

  /// Whether anything was asked for *just now*, as opposed to where the customer lives.
  ///
  /// The two are cleared by different controls and must not be confused: a Clear that could reach
  /// the district would undo a preference set once and expected to stay.
  bool get hasSearchTerms => categoryId != null || keyword.isNotEmpty;

  /// What the search is sent, or null for no district narrowing at all.
  List<String>? get districtIdsOrNull =>
      districtIds.isEmpty ? null : districtIds.toList();

  CustomerSearchFilter copyWith({
    String? categoryId,
    String? keyword,
    Set<String>? stateIds,
    Set<String>? districtIds,
    String? primaryDistrictName,
    bool clearCategory = false,
    bool clearPrimaryDistrictName = false,
  }) => CustomerSearchFilter(
    categoryId: clearCategory ? null : (categoryId ?? this.categoryId),
    keyword: keyword ?? this.keyword,
    stateIds: stateIds ?? this.stateIds,
    districtIds: districtIds ?? this.districtIds,
    primaryDistrictName: clearPrimaryDistrictName
        ? null
        : (primaryDistrictName ?? this.primaryDistrictName),
  );
}

@Riverpod(keepAlive: true)
class CustomerSearchFilterNotifier extends _$CustomerSearchFilterNotifier {
  static const _keyStateIds = 'customer_filter_state_ids';
  static const _keyDistrictIds = 'customer_filter_district_ids';
  static const _keyPrimaryName = 'customer_filter_primary_district';

  @override
  CustomerSearchFilter build() {
    // Read in the background rather than awaited: the home screen must not hold on a spinner waiting
    // for disk. It opens showing everywhere and narrows a frame later if a district was saved.
    unawaited(_restore());
    return const CustomerSearchFilter();
  }

  /// Brings back the district the customer last chose.
  ///
  /// Only the location. Picking where you live is a once-ever act, and an app that forgot it on
  /// every launch would make the nearby services it exists to surface the hardest thing to reach.
  Future<void> _restore() async {
    try {
      final store = await SharedPreferences.getInstance();
      final districtIds = store.getStringList(_keyDistrictIds);

      if (districtIds == null || districtIds.isEmpty) return;

      // Only if nothing has been chosen since: somebody who set a district while this was loading
      // must not have it overwritten by where they were yesterday.
      if (state.hasLocation) return;

      state = state.copyWith(
        stateIds: store.getStringList(_keyStateIds)?.toSet() ?? const {},
        districtIds: districtIds.toSet(),
        primaryDistrictName: store.getString(_keyPrimaryName),
      );
    } on Exception {
      // A remembered district that cannot be read is not worth an error on screen — the customer
      // simply starts at everywhere, and the picker still works.
    }
  }

  Future<void> _saveLocation() async {
    try {
      final store = await SharedPreferences.getInstance();
      final filter = state;

      if (!filter.hasLocation) {
        await store.remove(_keyStateIds);
        await store.remove(_keyDistrictIds);
        await store.remove(_keyPrimaryName);
        return;
      }

      await store.setStringList(_keyStateIds, filter.stateIds.toList());
      await store.setStringList(_keyDistrictIds, filter.districtIds.toList());

      if (filter.primaryDistrictName case final name?) {
        await store.setString(_keyPrimaryName, name);
      } else {
        await store.remove(_keyPrimaryName);
      }
    } on Exception {
      // Failing to remember is a small loss; failing loudly would be a larger one.
    }
  }

  /// Chooses a category, or clears it when the one already chosen is tapped again.
  ///
  /// For the grid, where tapping the tile that is already lit is how somebody turns it off.
  void toggleCategory(String? categoryId) {
    state = categoryId == null || categoryId == state.categoryId
        ? state.copyWith(clearCategory: true)
        : state.copyWith(categoryId: categoryId);
  }

  /// Chooses a category outright. Null means every category.
  ///
  /// For the all-categories list, where choosing the row already ticked means "this one" rather than
  /// "turn it off" — toggling there would leave somebody staring at a filter they just re-picked.
  void setCategory(String? categoryId) {
    state = categoryId == null
        ? state.copyWith(clearCategory: true)
        : state.copyWith(categoryId: categoryId);
  }

  void setKeyword(String keyword) {
    state = state.copyWith(keyword: keyword.trim());
  }

  void setLocation({
    required Set<String> stateIds,
    required Set<String> districtIds,
    required String? primaryDistrictName,
  }) {
    state = CustomerSearchFilter(
      categoryId: state.categoryId,
      keyword: state.keyword,
      stateIds: stateIds,
      districtIds: districtIds,
      primaryDistrictName: primaryDistrictName,
    );
    _saveLocation();
  }

  /// Back to everywhere, keeping what they were searching for.
  ///
  /// Reached from inside the location picker, which is the only place that offers it: a customer who
  /// set their district meant it, and a stray tap elsewhere should not silently widen their results
  /// back to the whole country.
  void clearLocation() {
    state = CustomerSearchFilter(
      categoryId: state.categoryId,
      keyword: state.keyword,
    );
    _saveLocation();
  }

  /// Clears what they were looking for, and leaves where they are alone.
  ///
  /// This is what the Clear beside "Matching services" does. It used to clear the location too,
  /// which made it the one control that could undo a standing preference by accident — and there is
  /// already a Clear location inside the picker for when that is what somebody wants.
  void clearSearch() {
    state = CustomerSearchFilter(
      stateIds: state.stateIds,
      districtIds: state.districtIds,
      primaryDistrictName: state.primaryDistrictName,
    );
  }
}
