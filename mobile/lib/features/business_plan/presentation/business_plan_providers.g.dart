// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'business_plan_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(businessPlanRepository)
final businessPlanRepositoryProvider = BusinessPlanRepositoryProvider._();

final class BusinessPlanRepositoryProvider
    extends
        $FunctionalProvider<
          BusinessPlanRepository,
          BusinessPlanRepository,
          BusinessPlanRepository
        >
    with $Provider<BusinessPlanRepository> {
  BusinessPlanRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'businessPlanRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$businessPlanRepositoryHash();

  @$internal
  @override
  $ProviderElement<BusinessPlanRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  BusinessPlanRepository create(Ref ref) {
    return businessPlanRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(BusinessPlanRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<BusinessPlanRepository>(value),
    );
  }
}

String _$businessPlanRepositoryHash() =>
    r'ecdaf40f85891cc5b15e9f7195c7d19190db52f4';

/// The business's plan and its use in each area. Read afresh whenever a screen asks for it again,
/// so a listing just added or a plan just bought shows at once.

@ProviderFor(businessPlan)
final businessPlanProvider = BusinessPlanProvider._();

/// The business's plan and its use in each area. Read afresh whenever a screen asks for it again,
/// so a listing just added or a plan just bought shows at once.

final class BusinessPlanProvider
    extends
        $FunctionalProvider<
          AsyncValue<BusinessPlan>,
          BusinessPlan,
          FutureOr<BusinessPlan>
        >
    with $FutureModifier<BusinessPlan>, $FutureProvider<BusinessPlan> {
  /// The business's plan and its use in each area. Read afresh whenever a screen asks for it again,
  /// so a listing just added or a plan just bought shows at once.
  BusinessPlanProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'businessPlanProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$businessPlanHash();

  @$internal
  @override
  $FutureProviderElement<BusinessPlan> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<BusinessPlan> create(Ref ref) {
    return businessPlan(ref);
  }
}

String _$businessPlanHash() => r'0a5474666881dda26a37e6c6bd4e5cfa052c1112';
