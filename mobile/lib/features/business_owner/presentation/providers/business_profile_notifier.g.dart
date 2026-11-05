// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'business_profile_notifier.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(BusinessProfileNotifier)
final businessProfileProvider = BusinessProfileNotifierProvider._();

final class BusinessProfileNotifierProvider
    extends $AsyncNotifierProvider<BusinessProfileNotifier, BusinessProfile> {
  BusinessProfileNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'businessProfileProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$businessProfileNotifierHash();

  @$internal
  @override
  BusinessProfileNotifier create() => BusinessProfileNotifier();
}

String _$businessProfileNotifierHash() =>
    r'9858a8afa9f90b4113a3070de6788362ab1d4c81';

abstract class _$BusinessProfileNotifier
    extends $AsyncNotifier<BusinessProfile> {
  FutureOr<BusinessProfile> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<BusinessProfile>, BusinessProfile>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<BusinessProfile>, BusinessProfile>,
              AsyncValue<BusinessProfile>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
