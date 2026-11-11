import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:zuno/features/auth/presentation/providers/auth_notifier.dart';
import 'package:zuno/features/auth/presentation/providers/auth_state.dart';
import 'package:zuno/features/customer/presentation/providers/customer_home_location_provider.dart';
import 'package:zuno/features/customer/presentation/providers/customer_search_filter_provider.dart';
import 'package:zuno/features/rental/domain/entities/rental_customer.dart';
import 'package:zuno/features/rental/presentation/providers/rental_order_providers.dart';

part 'rental_customer_providers.g.dart';

/// Which business line the customer is browsing: Service (the app as it was) or Rent.
enum CustomerPanel { service, rent }

/// The panel the customer has open. Every login opens on Service; Rent is one tap away and holds
/// only until the next login, so a customer never lands on Rent without choosing it.
@Riverpod(keepAlive: true)
class CustomerPanelChoice extends _$CustomerPanelChoice {
  @override
  CustomerPanel build() {
    // Rebuilt, so back to Service, when someone logs out or in; a profile refresh keeps the choice.
    ref.watch(
      authProvider.select(
        (auth) => switch (auth.value) {
          AuthAuthenticated(:final user) => user.id,
          _ => null,
        },
      ),
    );
    return CustomerPanel.service;
  }

  void choose(CustomerPanel panel) => state = panel;
}

/// Which shuffle the Rent home is showing. A pull to refresh rolls a new one.
@Riverpod(keepAlive: true)
class RentalHomeSeed extends _$RentalHomeSeed {
  @override
  int build() => DateTime.now().millisecondsSinceEpoch % 1000000;

  void reroll() => state = Random().nextInt(1000000);
}

/// What the customer is looking for in Rent: a category and words. The district is the app's one
/// location, shared with Service ([customerSearchFilterProvider]).
class RentalBrowseFilter {
  const RentalBrowseFilter({this.categoryId, this.keyword = ''});

  final String? categoryId;
  final String keyword;

  bool get isSearching => categoryId != null || keyword.isNotEmpty;
}

/// Kept alive: the Rent home is rebuilt every time the customer comes back from another tab.
@Riverpod(keepAlive: true)
class RentalBrowse extends _$RentalBrowse {
  @override
  RentalBrowseFilter build() => const RentalBrowseFilter();

  /// The same category again clears it, as on the Service home.
  void toggleCategory(String? id) => state = RentalBrowseFilter(
    categoryId: state.categoryId == id ? null : id,
    keyword: state.keyword,
  );

  /// Set, not toggled: picking from the full list means "this one".
  void setCategory(String? id) =>
      state = RentalBrowseFilter(categoryId: id, keyword: state.keyword);

  void setKeyword(String keyword) => state = RentalBrowseFilter(
    categoryId: state.categoryId,
    keyword: keyword.trim(),
  );

  void clear() => state = const RentalBrowseFilter();
}

/// The shared location's districts, sorted — a stable key for the lists below.
@riverpod
List<String> rentalDistrictIds(Ref ref) =>
    (ref.watch(customerSearchFilterProvider).districtIds.toList()..sort());

/// The Rent home for the current shuffle and location.
@riverpod
Future<List<RentalHomeSection>> rentalHome(Ref ref) {
  final seed = ref.watch(rentalHomeSeedProvider);
  final districts = ref.watch(rentalDistrictIdsProvider);
  return ref.watch(rentalCustomerRepositoryProvider).home(seed, districts);
}

/// The featured items at the top of the Rent home — the same all day, others tomorrow.
@riverpod
Future<List<RentalCard>> rentalBanners(Ref ref) => ref
    .watch(rentalCustomerRepositoryProvider)
    .banners(ref.watch(rentalDistrictIdsProvider));

/// What matches the category and words the customer chose, near them.
@riverpod
Future<List<RentalCard>> rentalSearch(Ref ref) {
  final filter = ref.watch(rentalBrowseProvider);
  return ref
      .watch(rentalCustomerRepositoryProvider)
      .search(
        categoryId: filter.categoryId,
        keyword: filter.keyword,
        districtIds: ref.watch(rentalDistrictIdsProvider),
      );
}

/// One rent item as a customer opens it.
@riverpod
Future<RentalItemDetail> rentalItemDetail(Ref ref, String id) =>
    ref.watch(rentalCustomerRepositoryProvider).item(id);

/// "Recommended rentals near you": what can be rented in the customer's own district — set up on
/// first open and kept in their account. Not the search filter. Empty when no location is set.
@riverpod
Future<List<RentalCard>> rentalRecommended(Ref ref) {
  final districtId = ref.watch(
    customerHomeLocationProvider.select((l) => l.district?.id),
  );
  if (districtId == null) return Future.value(const []);
  return ref
      .watch(rentalCustomerRepositoryProvider)
      .search(districtIds: [districtId]);
}
