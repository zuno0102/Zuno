// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'customer_bookings_notifier.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The customer's own orders, and every action that changes them.
///
/// Auto-disposed, and the actions below are reached from screens that do not watch it — Book service
/// is opened from search, which never touches this list. So reading the notifier creates it with no
/// listener, and Riverpod disposes it while the request is still in flight. Touching `ref` after that
/// throws "Cannot use the Ref of customerBookingsProvider after it has been disposed", which is what
/// a customer saw on the booking form after their order had in fact been placed.
///
/// Two rules keep every method below safe, and new ones must follow them:
///
///   * take what you need from `ref` **before** the first await — a repository read afterwards is
///     reading from a corpse;
///   * check `ref.mounted` before writing state afterwards. Skipping the refresh is correct rather
///     than a loss: a disposed provider holds no state worth refreshing, and the next screen to watch
///     it builds a new one that fetches.

@ProviderFor(CustomerBookingsNotifier)
final customerBookingsProvider = CustomerBookingsNotifierProvider._();

/// The customer's own orders, and every action that changes them.
///
/// Auto-disposed, and the actions below are reached from screens that do not watch it — Book service
/// is opened from search, which never touches this list. So reading the notifier creates it with no
/// listener, and Riverpod disposes it while the request is still in flight. Touching `ref` after that
/// throws "Cannot use the Ref of customerBookingsProvider after it has been disposed", which is what
/// a customer saw on the booking form after their order had in fact been placed.
///
/// Two rules keep every method below safe, and new ones must follow them:
///
///   * take what you need from `ref` **before** the first await — a repository read afterwards is
///     reading from a corpse;
///   * check `ref.mounted` before writing state afterwards. Skipping the refresh is correct rather
///     than a loss: a disposed provider holds no state worth refreshing, and the next screen to watch
///     it builds a new one that fetches.
final class CustomerBookingsNotifierProvider
    extends $AsyncNotifierProvider<CustomerBookingsNotifier, List<Booking>> {
  /// The customer's own orders, and every action that changes them.
  ///
  /// Auto-disposed, and the actions below are reached from screens that do not watch it — Book service
  /// is opened from search, which never touches this list. So reading the notifier creates it with no
  /// listener, and Riverpod disposes it while the request is still in flight. Touching `ref` after that
  /// throws "Cannot use the Ref of customerBookingsProvider after it has been disposed", which is what
  /// a customer saw on the booking form after their order had in fact been placed.
  ///
  /// Two rules keep every method below safe, and new ones must follow them:
  ///
  ///   * take what you need from `ref` **before** the first await — a repository read afterwards is
  ///     reading from a corpse;
  ///   * check `ref.mounted` before writing state afterwards. Skipping the refresh is correct rather
  ///     than a loss: a disposed provider holds no state worth refreshing, and the next screen to watch
  ///     it builds a new one that fetches.
  CustomerBookingsNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'customerBookingsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$customerBookingsNotifierHash();

  @$internal
  @override
  CustomerBookingsNotifier create() => CustomerBookingsNotifier();
}

String _$customerBookingsNotifierHash() =>
    r'b466812e877dd8e77ee27c0181649139ea78b274';

/// The customer's own orders, and every action that changes them.
///
/// Auto-disposed, and the actions below are reached from screens that do not watch it — Book service
/// is opened from search, which never touches this list. So reading the notifier creates it with no
/// listener, and Riverpod disposes it while the request is still in flight. Touching `ref` after that
/// throws "Cannot use the Ref of customerBookingsProvider after it has been disposed", which is what
/// a customer saw on the booking form after their order had in fact been placed.
///
/// Two rules keep every method below safe, and new ones must follow them:
///
///   * take what you need from `ref` **before** the first await — a repository read afterwards is
///     reading from a corpse;
///   * check `ref.mounted` before writing state afterwards. Skipping the refresh is correct rather
///     than a loss: a disposed provider holds no state worth refreshing, and the next screen to watch
///     it builds a new one that fetches.

abstract class _$CustomerBookingsNotifier
    extends $AsyncNotifier<List<Booking>> {
  FutureOr<List<Booking>> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<List<Booking>>, List<Booking>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<List<Booking>>, List<Booking>>,
              AsyncValue<List<Booking>>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
