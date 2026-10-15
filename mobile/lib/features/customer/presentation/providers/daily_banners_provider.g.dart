// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'daily_banners_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The services on today's home banner.
///
/// Which seven, and when they change, is the server's decision — so the app asks once and keeps the
/// answer. Kept alive because the customer shell rebuilds the home tab every time somebody comes back
/// from Bookings, and refetching a banner that only changes at midnight on each of those visits would
/// be a request for nothing.

@ProviderFor(dailyBanners)
final dailyBannersProvider = DailyBannersProvider._();

/// The services on today's home banner.
///
/// Which seven, and when they change, is the server's decision — so the app asks once and keeps the
/// answer. Kept alive because the customer shell rebuilds the home tab every time somebody comes back
/// from Bookings, and refetching a banner that only changes at midnight on each of those visits would
/// be a request for nothing.

final class DailyBannersProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<ServiceListing>>,
          List<ServiceListing>,
          FutureOr<List<ServiceListing>>
        >
    with
        $FutureModifier<List<ServiceListing>>,
        $FutureProvider<List<ServiceListing>> {
  /// The services on today's home banner.
  ///
  /// Which seven, and when they change, is the server's decision — so the app asks once and keeps the
  /// answer. Kept alive because the customer shell rebuilds the home tab every time somebody comes back
  /// from Bookings, and refetching a banner that only changes at midnight on each of those visits would
  /// be a request for nothing.
  DailyBannersProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'dailyBannersProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$dailyBannersHash();

  @$internal
  @override
  $FutureProviderElement<List<ServiceListing>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<ServiceListing>> create(Ref ref) {
    return dailyBanners(ref);
  }
}

String _$dailyBannersHash() => r'ace0aa18b6354397f2c976335839cb795b3d08f2';

/// Which shuffle the home screen is showing.
///
/// Re-rolled when somebody pulls to refresh, and only then. The server shuffles the catalogue by
/// whatever seed it is given, so a new one brings back a different set of services while an ordinary
/// rebuild — coming back from Bookings, say — keeps the page exactly where they left it.
///
/// Held in the app rather than decided by the server because only the app can tell those two apart.

@ProviderFor(HomeShuffleSeed)
final homeShuffleSeedProvider = HomeShuffleSeedProvider._();

/// Which shuffle the home screen is showing.
///
/// Re-rolled when somebody pulls to refresh, and only then. The server shuffles the catalogue by
/// whatever seed it is given, so a new one brings back a different set of services while an ordinary
/// rebuild — coming back from Bookings, say — keeps the page exactly where they left it.
///
/// Held in the app rather than decided by the server because only the app can tell those two apart.
final class HomeShuffleSeedProvider
    extends $NotifierProvider<HomeShuffleSeed, int> {
  /// Which shuffle the home screen is showing.
  ///
  /// Re-rolled when somebody pulls to refresh, and only then. The server shuffles the catalogue by
  /// whatever seed it is given, so a new one brings back a different set of services while an ordinary
  /// rebuild — coming back from Bookings, say — keeps the page exactly where they left it.
  ///
  /// Held in the app rather than decided by the server because only the app can tell those two apart.
  HomeShuffleSeedProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'homeShuffleSeedProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$homeShuffleSeedHash();

  @$internal
  @override
  HomeShuffleSeed create() => HomeShuffleSeed();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(int value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<int>(value),
    );
  }
}

String _$homeShuffleSeedHash() => r'bbbbbfdff82287f59ec5bfdadced0e243ccaa00e';

/// Which shuffle the home screen is showing.
///
/// Re-rolled when somebody pulls to refresh, and only then. The server shuffles the catalogue by
/// whatever seed it is given, so a new one brings back a different set of services while an ordinary
/// rebuild — coming back from Bookings, say — keeps the page exactly where they left it.
///
/// Held in the app rather than decided by the server because only the app can tell those two apart.

abstract class _$HomeShuffleSeed extends $Notifier<int> {
  int build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<int, int>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<int, int>,
              int,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// Every section of the home screen, in one answer.
///
/// One request rather than four: the sections are composed against each other so nothing repeats
/// between them, which only the server can do.
///
/// Kept alive because it changes with the catalogue, not with what the customer is filtering by, and
/// the home tab is rebuilt every time they come back from another tab.
///
/// Deliberately unfiltered. What the customer is looking for narrows the band of results shown
/// *above* these sections; the sections themselves stay the catalogue, so a district with four
/// businesses in it does not reduce the whole home screen to four cards.

@ProviderFor(homeSections)
final homeSectionsProvider = HomeSectionsProvider._();

/// Every section of the home screen, in one answer.
///
/// One request rather than four: the sections are composed against each other so nothing repeats
/// between them, which only the server can do.
///
/// Kept alive because it changes with the catalogue, not with what the customer is filtering by, and
/// the home tab is rebuilt every time they come back from another tab.
///
/// Deliberately unfiltered. What the customer is looking for narrows the band of results shown
/// *above* these sections; the sections themselves stay the catalogue, so a district with four
/// businesses in it does not reduce the whole home screen to four cards.

final class HomeSectionsProvider
    extends
        $FunctionalProvider<
          AsyncValue<HomeSections>,
          HomeSections,
          FutureOr<HomeSections>
        >
    with $FutureModifier<HomeSections>, $FutureProvider<HomeSections> {
  /// Every section of the home screen, in one answer.
  ///
  /// One request rather than four: the sections are composed against each other so nothing repeats
  /// between them, which only the server can do.
  ///
  /// Kept alive because it changes with the catalogue, not with what the customer is filtering by, and
  /// the home tab is rebuilt every time they come back from another tab.
  ///
  /// Deliberately unfiltered. What the customer is looking for narrows the band of results shown
  /// *above* these sections; the sections themselves stay the catalogue, so a district with four
  /// businesses in it does not reduce the whole home screen to four cards.
  HomeSectionsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'homeSectionsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$homeSectionsHash();

  @$internal
  @override
  $FutureProviderElement<HomeSections> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<HomeSections> create(Ref ref) {
    return homeSections(ref);
  }
}

String _$homeSectionsHash() => r'e2e6209c5e6f7785df78c10b19e2d8d152f37ed4';
