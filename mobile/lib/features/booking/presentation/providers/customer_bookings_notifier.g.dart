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
/// Orders waiting on the customer — the number on the Bookings tab.
///
/// Things only the customer can move forward: the business sent a price or crew offer that needs an
/// answer, or a finished job is waiting for its rating.
/// Counted only while the customer has not looked.
///
/// The number still means "you have something to do here" — an offer to answer, a job to rate —
/// but it stops counting an order once they have opened it, and starts again the moment the
/// business does something new on it. Before this it counted the state alone, so reading the
/// booking changed nothing and the badge sat there afterwards saying something the customer had
/// already seen.
///
/// Tied to the same unread notifications the bell counts, so opening an order moves both numbers
/// at once, whichever way it was opened.

@ProviderFor(customerBookingsNeedingMeCount)
final customerBookingsNeedingMeCountProvider =
    CustomerBookingsNeedingMeCountProvider._();

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
/// Orders waiting on the customer — the number on the Bookings tab.
///
/// Things only the customer can move forward: the business sent a price or crew offer that needs an
/// answer, or a finished job is waiting for its rating.
/// Counted only while the customer has not looked.
///
/// The number still means "you have something to do here" — an offer to answer, a job to rate —
/// but it stops counting an order once they have opened it, and starts again the moment the
/// business does something new on it. Before this it counted the state alone, so reading the
/// booking changed nothing and the badge sat there afterwards saying something the customer had
/// already seen.
///
/// Tied to the same unread notifications the bell counts, so opening an order moves both numbers
/// at once, whichever way it was opened.

final class CustomerBookingsNeedingMeCountProvider
    extends $FunctionalProvider<int, int, int>
    with $Provider<int> {
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
  /// Orders waiting on the customer — the number on the Bookings tab.
  ///
  /// Things only the customer can move forward: the business sent a price or crew offer that needs an
  /// answer, or a finished job is waiting for its rating.
  /// Counted only while the customer has not looked.
  ///
  /// The number still means "you have something to do here" — an offer to answer, a job to rate —
  /// but it stops counting an order once they have opened it, and starts again the moment the
  /// business does something new on it. Before this it counted the state alone, so reading the
  /// booking changed nothing and the badge sat there afterwards saying something the customer had
  /// already seen.
  ///
  /// Tied to the same unread notifications the bell counts, so opening an order moves both numbers
  /// at once, whichever way it was opened.
  CustomerBookingsNeedingMeCountProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'customerBookingsNeedingMeCountProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$customerBookingsNeedingMeCountHash();

  @$internal
  @override
  $ProviderElement<int> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  int create(Ref ref) {
    return customerBookingsNeedingMeCount(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(int value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<int>(value),
    );
  }
}

String _$customerBookingsNeedingMeCountHash() =>
    r'0ee552f7c7f0886dbc60ce8b25d2059373b55ba5';

@ProviderFor(CustomerBookingsNotifier)
final customerBookingsProvider = CustomerBookingsNotifierProvider._();

final class CustomerBookingsNotifierProvider
    extends $AsyncNotifierProvider<CustomerBookingsNotifier, List<Booking>> {
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
    r'85c392306d17a10aec204adbcf41630dd2f15525';

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
