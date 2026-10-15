import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:zuno/features/customer/domain/entities/service_listing.dart';
import 'package:zuno/features/customer/presentation/providers/customer_providers.dart';
import 'package:zuno/features/customer/presentation/providers/customer_search_filter_provider.dart';

part 'service_search_notifier.g.dart';

/// What the customer's home screen lists.
///
/// Separate from the business search because they answer different questions — one is "what
/// can I book", the other "who are they" — and a customer starts with the first.
///
/// Reads the filter rather than being told what to search for. It used to keep the criteria in
/// mutable private fields, which is only as durable as the notifier: the customer shell disposes the
/// search tab when another tab opens, this went with it, and the rebuild searched with every field
/// back at null — so coming back from Bookings silently widened the results to the whole country.
///
/// Kept alive for the same reason. Changing the filter refetches, because that is a new question;
/// leaving the tab or minimising the app does not, because the question has not changed.
@Riverpod(keepAlive: true)
class ServiceSearchNotifier extends _$ServiceSearchNotifier {
  @override
  Future<List<ServiceListing>> build() {
    final filter = ref.watch(customerSearchFilterProvider);

    return ref
        .watch(customerRepositoryProvider)
        .searchServices(
          categoryId: filter.categoryId,
          keyword: filter.keyword.isEmpty ? null : filter.keyword,
          districtIds: filter.districtIdsOrNull,
        );
  }

  /// Runs the current filter again, for pull-to-refresh.
  ///
  /// Not for changing the search: that is done by changing the filter, which refetches on its own.
  Future<void> refresh() async {
    final filter = ref.read(customerSearchFilterProvider);

    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(customerRepositoryProvider).searchServices(
        categoryId: filter.categoryId,
        keyword: filter.keyword.isEmpty ? null : filter.keyword,
        districtIds: filter.districtIdsOrNull,
      ),
    );
  }
}
