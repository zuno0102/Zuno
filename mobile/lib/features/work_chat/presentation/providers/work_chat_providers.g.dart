// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'work_chat_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(workMessageDataSource)
final workMessageDataSourceProvider = WorkMessageDataSourceProvider._();

final class WorkMessageDataSourceProvider
    extends
        $FunctionalProvider<
          WorkMessageRemoteDataSource,
          WorkMessageRemoteDataSource,
          WorkMessageRemoteDataSource
        >
    with $Provider<WorkMessageRemoteDataSource> {
  WorkMessageDataSourceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'workMessageDataSourceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$workMessageDataSourceHash();

  @$internal
  @override
  $ProviderElement<WorkMessageRemoteDataSource> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  WorkMessageRemoteDataSource create(Ref ref) {
    return workMessageDataSource(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(WorkMessageRemoteDataSource value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<WorkMessageRemoteDataSource>(value),
    );
  }
}

String _$workMessageDataSourceHash() =>
    r'1d889696297b807e29d2b05a8f1757e35c1312f9';

/// Every business–worker conversation the signed-in user has — what the Messages lists show.
///
/// Polled like the booking chat list, so a reply shows up as a count without anyone refreshing.
/// Signed out, it asks nothing.

@ProviderFor(WorkThreads)
final workThreadsProvider = WorkThreadsProvider._();

/// Every business–worker conversation the signed-in user has — what the Messages lists show.
///
/// Polled like the booking chat list, so a reply shows up as a count without anyone refreshing.
/// Signed out, it asks nothing.
final class WorkThreadsProvider
    extends $AsyncNotifierProvider<WorkThreads, List<WorkThread>> {
  /// Every business–worker conversation the signed-in user has — what the Messages lists show.
  ///
  /// Polled like the booking chat list, so a reply shows up as a count without anyone refreshing.
  /// Signed out, it asks nothing.
  WorkThreadsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'workThreadsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$workThreadsHash();

  @$internal
  @override
  WorkThreads create() => WorkThreads();
}

String _$workThreadsHash() => r'5f8a7e300a7c459c552821623d23c26623a2c719';

/// Every business–worker conversation the signed-in user has — what the Messages lists show.
///
/// Polled like the booking chat list, so a reply shows up as a count without anyone refreshing.
/// Signed out, it asks nothing.

abstract class _$WorkThreads extends $AsyncNotifier<List<WorkThread>> {
  FutureOr<List<WorkThread>> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref as $Ref<AsyncValue<List<WorkThread>>, List<WorkThread>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<List<WorkThread>>, List<WorkThread>>,
              AsyncValue<List<WorkThread>>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// Unread business–worker messages across every conversation.

@ProviderFor(unreadWorkChatCount)
final unreadWorkChatCountProvider = UnreadWorkChatCountProvider._();

/// Unread business–worker messages across every conversation.

final class UnreadWorkChatCountProvider
    extends $FunctionalProvider<int, int, int>
    with $Provider<int> {
  /// Unread business–worker messages across every conversation.
  UnreadWorkChatCountProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'unreadWorkChatCountProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$unreadWorkChatCountHash();

  @$internal
  @override
  $ProviderElement<int> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  int create(Ref ref) {
    return unreadWorkChatCount(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(int value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<int>(value),
    );
  }
}

String _$unreadWorkChatCountHash() =>
    r'b6d0f7f4ed261fe26369a431bc0a875594d15d94';

/// One business–worker conversation, kept fresh while it is open — polled for the same reasons as
/// a booking conversation, and stopped when the screen closes.

@ProviderFor(WorkConversation)
final workConversationProvider = WorkConversationFamily._();

/// One business–worker conversation, kept fresh while it is open — polled for the same reasons as
/// a booking conversation, and stopped when the screen closes.
final class WorkConversationProvider
    extends $AsyncNotifierProvider<WorkConversation, List<BookingMessage>> {
  /// One business–worker conversation, kept fresh while it is open — polled for the same reasons as
  /// a booking conversation, and stopped when the screen closes.
  WorkConversationProvider._({
    required WorkConversationFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'workConversationProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$workConversationHash();

  @override
  String toString() {
    return r'workConversationProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  WorkConversation create() => WorkConversation();

  @override
  bool operator ==(Object other) {
    return other is WorkConversationProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$workConversationHash() => r'83e0917b7bbeb82bfebd9ecff2d4228e9746ddd5';

/// One business–worker conversation, kept fresh while it is open — polled for the same reasons as
/// a booking conversation, and stopped when the screen closes.

final class WorkConversationFamily extends $Family
    with
        $ClassFamilyOverride<
          WorkConversation,
          AsyncValue<List<BookingMessage>>,
          List<BookingMessage>,
          FutureOr<List<BookingMessage>>,
          String
        > {
  WorkConversationFamily._()
    : super(
        retry: null,
        name: r'workConversationProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// One business–worker conversation, kept fresh while it is open — polled for the same reasons as
  /// a booking conversation, and stopped when the screen closes.

  WorkConversationProvider call(String counterpartId) =>
      WorkConversationProvider._(argument: counterpartId, from: this);

  @override
  String toString() => r'workConversationProvider';
}

/// One business–worker conversation, kept fresh while it is open — polled for the same reasons as
/// a booking conversation, and stopped when the screen closes.

abstract class _$WorkConversation extends $AsyncNotifier<List<BookingMessage>> {
  late final _$args = ref.$arg as String;
  String get counterpartId => _$args;

  FutureOr<List<BookingMessage>> build(String counterpartId);
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref
            as $Ref<AsyncValue<List<BookingMessage>>, List<BookingMessage>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                AsyncValue<List<BookingMessage>>,
                List<BookingMessage>
              >,
              AsyncValue<List<BookingMessage>>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, () => build(_$args));
  }
}
