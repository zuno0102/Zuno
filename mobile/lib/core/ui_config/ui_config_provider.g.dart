// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ui_config_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The labels and colours in force, rebuilt when a newer copy arrives from the server.
///
/// Starts with what [loadStartupUiConfig] set, then asks the server once per launch — sending the
/// version it already has, so an unchanged config costs a 304 and no download.

@ProviderFor(UiConfigNotifier)
final uiConfigProvider = UiConfigNotifierProvider._();

/// The labels and colours in force, rebuilt when a newer copy arrives from the server.
///
/// Starts with what [loadStartupUiConfig] set, then asks the server once per launch — sending the
/// version it already has, so an unchanged config costs a 304 and no download.
final class UiConfigNotifierProvider
    extends $NotifierProvider<UiConfigNotifier, UiConfig> {
  /// The labels and colours in force, rebuilt when a newer copy arrives from the server.
  ///
  /// Starts with what [loadStartupUiConfig] set, then asks the server once per launch — sending the
  /// version it already has, so an unchanged config costs a 304 and no download.
  UiConfigNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'uiConfigProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$uiConfigNotifierHash();

  @$internal
  @override
  UiConfigNotifier create() => UiConfigNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(UiConfig value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<UiConfig>(value),
    );
  }
}

String _$uiConfigNotifierHash() => r'8997eee4b2655cc0ad7c37f03c2f7e4ccefddc20';

/// The labels and colours in force, rebuilt when a newer copy arrives from the server.
///
/// Starts with what [loadStartupUiConfig] set, then asks the server once per launch — sending the
/// version it already has, so an unchanged config costs a 304 and no download.

abstract class _$UiConfigNotifier extends $Notifier<UiConfig> {
  UiConfig build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<UiConfig, UiConfig>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<UiConfig, UiConfig>,
              UiConfig,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
