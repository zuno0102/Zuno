// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'place_search_sheet.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Looks a place up through our own server.
///
/// Never straight to the map provider: the search is proxied so one identifiable client makes the
/// calls, results are cached in one place, and a paid provider's key could be introduced later
/// without shipping it inside the app.

@ProviderFor(placeSearchClient)
final placeSearchClientProvider = PlaceSearchClientProvider._();

/// Looks a place up through our own server.
///
/// Never straight to the map provider: the search is proxied so one identifiable client makes the
/// calls, results are cached in one place, and a paid provider's key could be introduced later
/// without shipping it inside the app.

final class PlaceSearchClientProvider
    extends
        $FunctionalProvider<
          PlaceSearchClient,
          PlaceSearchClient,
          PlaceSearchClient
        >
    with $Provider<PlaceSearchClient> {
  /// Looks a place up through our own server.
  ///
  /// Never straight to the map provider: the search is proxied so one identifiable client makes the
  /// calls, results are cached in one place, and a paid provider's key could be introduced later
  /// without shipping it inside the app.
  PlaceSearchClientProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'placeSearchClientProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$placeSearchClientHash();

  @$internal
  @override
  $ProviderElement<PlaceSearchClient> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  PlaceSearchClient create(Ref ref) {
    return placeSearchClient(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(PlaceSearchClient value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<PlaceSearchClient>(value),
    );
  }
}

String _$placeSearchClientHash() => r'da886d0671c754ab2e7776d7117fded373ca963d';
