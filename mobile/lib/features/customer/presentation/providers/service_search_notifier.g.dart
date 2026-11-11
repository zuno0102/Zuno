// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'service_search_notifier.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
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

@ProviderFor(ServiceSearchNotifier)
final serviceSearchProvider = ServiceSearchNotifierProvider._();

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
final class ServiceSearchNotifierProvider
    extends
        $AsyncNotifierProvider<ServiceSearchNotifier, List<ServiceListing>> {
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
  ServiceSearchNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'serviceSearchProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$serviceSearchNotifierHash();

  @$internal
  @override
  ServiceSearchNotifier create() => ServiceSearchNotifier();
}

String _$serviceSearchNotifierHash() =>
    r'dba210eeddd6d05a97a31ccadea7a9670f429a45';

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

abstract class _$ServiceSearchNotifier
    extends $AsyncNotifier<List<ServiceListing>> {
  FutureOr<List<ServiceListing>> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref
            as $Ref<AsyncValue<List<ServiceListing>>, List<ServiceListing>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                AsyncValue<List<ServiceListing>>,
                List<ServiceListing>
              >,
              AsyncValue<List<ServiceListing>>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// "Recommended services near you": what is offered in the customer's own district — the one set up
/// on first open and kept in their account. Not the search filter: the listings below are unchanged
/// by it. Empty when no location is set.

@ProviderFor(recommendedServices)
final recommendedServicesProvider = RecommendedServicesProvider._();

/// "Recommended services near you": what is offered in the customer's own district — the one set up
/// on first open and kept in their account. Not the search filter: the listings below are unchanged
/// by it. Empty when no location is set.

final class RecommendedServicesProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<ServiceListing>>,
          List<ServiceListing>,
          FutureOr<List<ServiceListing>>
        >
    with
        $FutureModifier<List<ServiceListing>>,
        $FutureProvider<List<ServiceListing>> {
  /// "Recommended services near you": what is offered in the customer's own district — the one set up
  /// on first open and kept in their account. Not the search filter: the listings below are unchanged
  /// by it. Empty when no location is set.
  RecommendedServicesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'recommendedServicesProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$recommendedServicesHash();

  @$internal
  @override
  $FutureProviderElement<List<ServiceListing>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<ServiceListing>> create(Ref ref) {
    return recommendedServices(ref);
  }
}

String _$recommendedServicesHash() =>
    r'51c6c3358ec02d007645cdbed2be708e2c1dd7fa';
