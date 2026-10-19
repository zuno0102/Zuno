// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'booking_message_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(bookingMessageDataSource)
final bookingMessageDataSourceProvider = BookingMessageDataSourceProvider._();

final class BookingMessageDataSourceProvider
    extends
        $FunctionalProvider<
          BookingMessageRemoteDataSource,
          BookingMessageRemoteDataSource,
          BookingMessageRemoteDataSource
        >
    with $Provider<BookingMessageRemoteDataSource> {
  BookingMessageDataSourceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'bookingMessageDataSourceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$bookingMessageDataSourceHash();

  @$internal
  @override
  $ProviderElement<BookingMessageRemoteDataSource> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  BookingMessageRemoteDataSource create(Ref ref) {
    return bookingMessageDataSource(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(BookingMessageRemoteDataSource value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<BookingMessageRemoteDataSource>(
        value,
      ),
    );
  }
}

String _$bookingMessageDataSourceHash() =>
    r'772be0e7781058742bd3e4b0a871e4657fa504c4';

/// Every booking the signed-in user has a conversation on — what the Chat tab lists.
///
/// Kept alive and re-asked every few seconds while somebody is signed in, so a new message shows up
/// as a count on the Chat tab and in the list without anyone pulling to refresh — the way WhatsApp
/// shows "2" before you open anything. Signed out, it asks nothing.

@ProviderFor(BookingThreads)
final bookingThreadsProvider = BookingThreadsProvider._();

/// Every booking the signed-in user has a conversation on — what the Chat tab lists.
///
/// Kept alive and re-asked every few seconds while somebody is signed in, so a new message shows up
/// as a count on the Chat tab and in the list without anyone pulling to refresh — the way WhatsApp
/// shows "2" before you open anything. Signed out, it asks nothing.
final class BookingThreadsProvider
    extends $AsyncNotifierProvider<BookingThreads, List<BookingThread>> {
  /// Every booking the signed-in user has a conversation on — what the Chat tab lists.
  ///
  /// Kept alive and re-asked every few seconds while somebody is signed in, so a new message shows up
  /// as a count on the Chat tab and in the list without anyone pulling to refresh — the way WhatsApp
  /// shows "2" before you open anything. Signed out, it asks nothing.
  BookingThreadsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'bookingThreadsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$bookingThreadsHash();

  @$internal
  @override
  BookingThreads create() => BookingThreads();
}

String _$bookingThreadsHash() => r'da6a27f97fb4c70bf248ff88d7e32878be83751d';

/// Every booking the signed-in user has a conversation on — what the Chat tab lists.
///
/// Kept alive and re-asked every few seconds while somebody is signed in, so a new message shows up
/// as a count on the Chat tab and in the list without anyone pulling to refresh — the way WhatsApp
/// shows "2" before you open anything. Signed out, it asks nothing.

abstract class _$BookingThreads extends $AsyncNotifier<List<BookingThread>> {
  FutureOr<List<BookingThread>> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref as $Ref<AsyncValue<List<BookingThread>>, List<BookingThread>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<List<BookingThread>>, List<BookingThread>>,
              AsyncValue<List<BookingThread>>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// Unread messages across every conversation — the number on the Chat tab.

@ProviderFor(unreadChatCount)
final unreadChatCountProvider = UnreadChatCountProvider._();

/// Unread messages across every conversation — the number on the Chat tab.

final class UnreadChatCountProvider extends $FunctionalProvider<int, int, int>
    with $Provider<int> {
  /// Unread messages across every conversation — the number on the Chat tab.
  UnreadChatCountProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'unreadChatCountProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$unreadChatCountHash();

  @$internal
  @override
  $ProviderElement<int> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  int create(Ref ref) {
    return unreadChatCount(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(int value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<int>(value),
    );
  }
}

String _$unreadChatCountHash() => r'c3539910e04340461483439f56465716aa6a6546';

/// One booking's conversation, kept fresh while the thread is open.
///
/// Polled rather than pushed. The app has no socket and adding one for this would be a second way
/// for the server to talk to the client, with its own reconnection and auth story — real work, for a
/// screen somebody has open for a minute at a time. Every few seconds is close enough to live for
/// two people arranging a time, and the poll stops the moment the screen closes because the provider
/// is disposed with it.

@ProviderFor(BookingConversation)
final bookingConversationProvider = BookingConversationFamily._();

/// One booking's conversation, kept fresh while the thread is open.
///
/// Polled rather than pushed. The app has no socket and adding one for this would be a second way
/// for the server to talk to the client, with its own reconnection and auth story — real work, for a
/// screen somebody has open for a minute at a time. Every few seconds is close enough to live for
/// two people arranging a time, and the poll stops the moment the screen closes because the provider
/// is disposed with it.
final class BookingConversationProvider
    extends $AsyncNotifierProvider<BookingConversation, List<BookingMessage>> {
  /// One booking's conversation, kept fresh while the thread is open.
  ///
  /// Polled rather than pushed. The app has no socket and adding one for this would be a second way
  /// for the server to talk to the client, with its own reconnection and auth story — real work, for a
  /// screen somebody has open for a minute at a time. Every few seconds is close enough to live for
  /// two people arranging a time, and the poll stops the moment the screen closes because the provider
  /// is disposed with it.
  BookingConversationProvider._({
    required BookingConversationFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'bookingConversationProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$bookingConversationHash();

  @override
  String toString() {
    return r'bookingConversationProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  BookingConversation create() => BookingConversation();

  @override
  bool operator ==(Object other) {
    return other is BookingConversationProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$bookingConversationHash() =>
    r'75e25ea4321b0c42ef4b74f8364c3ae2259d25dc';

/// One booking's conversation, kept fresh while the thread is open.
///
/// Polled rather than pushed. The app has no socket and adding one for this would be a second way
/// for the server to talk to the client, with its own reconnection and auth story — real work, for a
/// screen somebody has open for a minute at a time. Every few seconds is close enough to live for
/// two people arranging a time, and the poll stops the moment the screen closes because the provider
/// is disposed with it.

final class BookingConversationFamily extends $Family
    with
        $ClassFamilyOverride<
          BookingConversation,
          AsyncValue<List<BookingMessage>>,
          List<BookingMessage>,
          FutureOr<List<BookingMessage>>,
          String
        > {
  BookingConversationFamily._()
    : super(
        retry: null,
        name: r'bookingConversationProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// One booking's conversation, kept fresh while the thread is open.
  ///
  /// Polled rather than pushed. The app has no socket and adding one for this would be a second way
  /// for the server to talk to the client, with its own reconnection and auth story — real work, for a
  /// screen somebody has open for a minute at a time. Every few seconds is close enough to live for
  /// two people arranging a time, and the poll stops the moment the screen closes because the provider
  /// is disposed with it.

  BookingConversationProvider call(String bookingId) =>
      BookingConversationProvider._(argument: bookingId, from: this);

  @override
  String toString() => r'bookingConversationProvider';
}

/// One booking's conversation, kept fresh while the thread is open.
///
/// Polled rather than pushed. The app has no socket and adding one for this would be a second way
/// for the server to talk to the client, with its own reconnection and auth story — real work, for a
/// screen somebody has open for a minute at a time. Every few seconds is close enough to live for
/// two people arranging a time, and the poll stops the moment the screen closes because the provider
/// is disposed with it.

abstract class _$BookingConversation
    extends $AsyncNotifier<List<BookingMessage>> {
  late final _$args = ref.$arg as String;
  String get bookingId => _$args;

  FutureOr<List<BookingMessage>> build(String bookingId);
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
