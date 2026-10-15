// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'business_dashboard_notifier.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(businessDashboard)
final businessDashboardProvider = BusinessDashboardProvider._();

final class BusinessDashboardProvider
    extends
        $FunctionalProvider<
          AsyncValue<BusinessDashboard>,
          BusinessDashboard,
          FutureOr<BusinessDashboard>
        >
    with
        $FutureModifier<BusinessDashboard>,
        $FutureProvider<BusinessDashboard> {
  BusinessDashboardProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'businessDashboardProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$businessDashboardHash();

  @$internal
  @override
  $FutureProviderElement<BusinessDashboard> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<BusinessDashboard> create(Ref ref) {
    return businessDashboard(ref);
  }
}

String _$businessDashboardHash() => r'bd7e6e536244c968e7e7fb97111908c8aa1ee4d4';
