import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zuno/features/customer/presentation/providers/customer_search_filter_provider.dart';

/// Where the customer lives, treated as a standing preference rather than a search.
///
/// Two rules come out of that, and both are easy to undo by accident:
///
///   * the district survives closing the app, so it is picked once rather than on every launch;
///   * a district on its own is not "filtering", so the home page keeps its sections — narrowed to
///     that district — instead of collapsing into a flat list of results for ever.
ProviderContainer _container() {
  final container = ProviderContainer();
  addTearDown(container.dispose);
  return container;
}

/// Lets the background restore in `build` finish before the state is read.
Future<void> _settle() => Future<void>.delayed(Duration.zero);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('what Clear beside the results clears', () {
    test('the category and the words, never the district', () {
      final container = _container();
      final notifier = container.read(customerSearchFilterProvider.notifier);
      notifier.setLocation(
        stateIds: {'tn'},
        districtIds: {'kanyakumari'},
        primaryDistrictName: 'Kanyakumari',
      );
      notifier.setCategory('cat-catering');
      notifier.setKeyword('wedding');

      notifier.clearSearch();

      final filter = container.read(customerSearchFilterProvider);
      expect(filter.categoryId, isNull);
      expect(filter.keyword, isEmpty);
      // The whole point: this control must not be able to undo where somebody lives.
      expect(filter.districtIds, {'kanyakumari'});
      expect(filter.primaryDistrictName, 'Kanyakumari');
    });

    test('clearing the location is still offered, from inside the picker', () {
      final container = _container();
      final notifier = container.read(customerSearchFilterProvider.notifier);
      notifier.setLocation(
        stateIds: {'tn'},
        districtIds: {'kanyakumari'},
        primaryDistrictName: 'Kanyakumari',
      );
      notifier.setKeyword('wedding');

      notifier.clearLocation();

      final filter = container.read(customerSearchFilterProvider);
      expect(filter.hasLocation, isFalse);
      // And it leaves the search alone, which is the other half of the separation.
      expect(filter.keyword, 'wedding');
    });
  });

  group('a district is not something searched for', () {
    test('it brings up the band of matches, but is not a term to clear', () {
      final container = _container();
      container
          .read(customerSearchFilterProvider.notifier)
          .setLocation(
            stateIds: {'tn'},
            districtIds: {'kanyakumari'},
            primaryDistrictName: 'Kanyakumari',
          );

      final filter = container.read(customerSearchFilterProvider);
      expect(filter.hasLocation, isTrue);
      // The matching band appears above the home sections...
      expect(filter.isFiltering, isTrue);
      // ...but no Clear is offered beside it, because the district is not what that button is for.
      expect(filter.hasSearchTerms, isFalse);
    });

    test('while a category or a keyword is', () {
      final container = _container();
      final notifier = container.read(customerSearchFilterProvider.notifier);

      notifier.setCategory('cat-catering');
      expect(
        container.read(customerSearchFilterProvider).hasSearchTerms,
        isTrue,
      );

      notifier.setCategory(null);
      notifier.setKeyword('plumber');
      expect(
        container.read(customerSearchFilterProvider).hasSearchTerms,
        isTrue,
      );

      notifier.setKeyword('');
      expect(
        container.read(customerSearchFilterProvider).hasSearchTerms,
        isFalse,
      );
      expect(container.read(customerSearchFilterProvider).isFiltering, isFalse);
    });
  });

  group('between launches', () {
    test('the district comes back', () async {
      final first = _container();
      first
          .read(customerSearchFilterProvider.notifier)
          .setLocation(
            stateIds: {'tn'},
            districtIds: {'kanyakumari', 'tirunelveli'},
            primaryDistrictName: 'Kanyakumari',
          );
      await _settle();

      // A second container is the app being opened again: new providers, same device storage.
      final next = _container();
      next.read(customerSearchFilterProvider);
      await _settle();

      final filter = next.read(customerSearchFilterProvider);
      expect(filter.districtIds, {'kanyakumari', 'tirunelveli'});
      expect(filter.stateIds, {'tn'});
      expect(filter.primaryDistrictName, 'Kanyakumari');
    });

    test('what they searched for does not', () async {
      final first = _container();
      final notifier = first.read(customerSearchFilterProvider.notifier);
      notifier.setLocation(
        stateIds: {'tn'},
        districtIds: {'kanyakumari'},
        primaryDistrictName: 'Kanyakumari',
      );
      notifier.setCategory('cat-catering');
      notifier.setKeyword('wedding');
      await _settle();

      final next = _container();
      next.read(customerSearchFilterProvider);
      await _settle();

      final filter = next.read(customerSearchFilterProvider);
      expect(filter.hasLocation, isTrue);
      // Reopening the app under yesterday's category is a filter nobody remembers setting.
      expect(filter.categoryId, isNull);
      expect(filter.keyword, isEmpty);
    });

    test('a cleared district stays cleared', () async {
      final first = _container();
      final notifier = first.read(customerSearchFilterProvider.notifier);
      notifier.setLocation(
        stateIds: {'tn'},
        districtIds: {'kanyakumari'},
        primaryDistrictName: 'Kanyakumari',
      );
      await _settle();
      notifier.clearLocation();
      await _settle();

      final next = _container();
      next.read(customerSearchFilterProvider);
      await _settle();

      expect(next.read(customerSearchFilterProvider).hasLocation, isFalse);
    });

    test('a district chosen while the saved one loads is not overwritten', () async {
      SharedPreferences.setMockInitialValues({
        'customer_filter_state_ids': ['ke'],
        'customer_filter_district_ids': ['kollam'],
        'customer_filter_primary_district': 'Kollam',
      });

      final container = _container();
      // Chosen in the same turn the restore was kicked off in — before it can finish.
      container
          .read(customerSearchFilterProvider.notifier)
          .setLocation(
            stateIds: {'tn'},
            districtIds: {'kanyakumari'},
            primaryDistrictName: 'Kanyakumari',
          );
      await _settle();

      expect(
        container.read(customerSearchFilterProvider).districtIds,
        {'kanyakumari'},
      );
    });
  });
}
