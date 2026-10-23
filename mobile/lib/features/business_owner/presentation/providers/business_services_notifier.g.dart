// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'business_services_notifier.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(BusinessServicesNotifier)
final businessServicesProvider = BusinessServicesNotifierProvider._();

final class BusinessServicesNotifierProvider
    extends
        $AsyncNotifierProvider<
          BusinessServicesNotifier,
          List<BusinessService>
        > {
  BusinessServicesNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'businessServicesProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$businessServicesNotifierHash();

  @$internal
  @override
  BusinessServicesNotifier create() => BusinessServicesNotifier();
}

String _$businessServicesNotifierHash() =>
    r'1f79d746b5e9b72a3d4b9f5c9bbebf9082a74ce6';

abstract class _$BusinessServicesNotifier
    extends $AsyncNotifier<List<BusinessService>> {
  FutureOr<List<BusinessService>> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref
            as $Ref<AsyncValue<List<BusinessService>>, List<BusinessService>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                AsyncValue<List<BusinessService>>,
                List<BusinessService>
              >,
              AsyncValue<List<BusinessService>>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
