// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'rental_payment_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The words for advances and payment methods, from the server's tables. Read once per session.

@ProviderFor(rentalPaymentOptions)
final rentalPaymentOptionsProvider = RentalPaymentOptionsProvider._();

/// The words for advances and payment methods, from the server's tables. Read once per session.

final class RentalPaymentOptionsProvider
    extends
        $FunctionalProvider<
          AsyncValue<RentalPaymentOptions>,
          RentalPaymentOptions,
          FutureOr<RentalPaymentOptions>
        >
    with
        $FutureModifier<RentalPaymentOptions>,
        $FutureProvider<RentalPaymentOptions> {
  /// The words for advances and payment methods, from the server's tables. Read once per session.
  RentalPaymentOptionsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'rentalPaymentOptionsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$rentalPaymentOptionsHash();

  @$internal
  @override
  $FutureProviderElement<RentalPaymentOptions> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<RentalPaymentOptions> create(Ref ref) {
    return rentalPaymentOptions(ref);
  }
}

String _$rentalPaymentOptionsHash() =>
    r'726fe93e08445d92842a67107886c87561c16253';

/// The business's UPI ID — what its order QR is made from. Null until it is set.

@ProviderFor(rentalUpiId)
final rentalUpiIdProvider = RentalUpiIdProvider._();

/// The business's UPI ID — what its order QR is made from. Null until it is set.

final class RentalUpiIdProvider
    extends $FunctionalProvider<AsyncValue<String?>, String?, FutureOr<String?>>
    with $FutureModifier<String?>, $FutureProvider<String?> {
  /// The business's UPI ID — what its order QR is made from. Null until it is set.
  RentalUpiIdProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'rentalUpiIdProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$rentalUpiIdHash();

  @$internal
  @override
  $FutureProviderElement<String?> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<String?> create(Ref ref) {
    return rentalUpiId(ref);
  }
}

String _$rentalUpiIdHash() => r'5b93e594f73bdd1b79f095d35fbd99418e27357d';

@ProviderFor(rentalPaymentWindow)
final rentalPaymentWindowProvider = RentalPaymentWindowProvider._();

final class RentalPaymentWindowProvider
    extends
        $FunctionalProvider<
          RentalPaymentWindow,
          RentalPaymentWindow,
          RentalPaymentWindow
        >
    with $Provider<RentalPaymentWindow> {
  RentalPaymentWindowProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'rentalPaymentWindowProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$rentalPaymentWindowHash();

  @$internal
  @override
  $ProviderElement<RentalPaymentWindow> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  RentalPaymentWindow create(Ref ref) {
    return rentalPaymentWindow(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(RentalPaymentWindow value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<RentalPaymentWindow>(value),
    );
  }
}

String _$rentalPaymentWindowHash() =>
    r'f4097ab336d7b4ec679cdbe4e60c5c58bd211b5f';
