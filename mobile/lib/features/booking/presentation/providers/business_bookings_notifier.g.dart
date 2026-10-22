// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'business_bookings_notifier.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(BusinessBookingsNotifier)
final businessBookingsProvider = BusinessBookingsNotifierProvider._();

final class BusinessBookingsNotifierProvider
    extends $AsyncNotifierProvider<BusinessBookingsNotifier, List<Booking>> {
  BusinessBookingsNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'businessBookingsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$businessBookingsNotifierHash();

  @$internal
  @override
  BusinessBookingsNotifier create() => BusinessBookingsNotifier();
}

String _$businessBookingsNotifierHash() =>
    r'5d8d2c72db47e6d1ec48e915aa9739333c96a030';

abstract class _$BusinessBookingsNotifier
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
