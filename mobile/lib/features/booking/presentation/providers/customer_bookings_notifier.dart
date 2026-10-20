import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:zuno/features/booking/domain/entities/booking.dart';
import 'package:zuno/features/booking/domain/repositories/booking_repository.dart';
import 'package:zuno/features/booking/presentation/providers/booking_providers.dart';
import 'package:zuno/features/notifications/presentation/providers/notification_providers.dart';

part 'customer_bookings_notifier.g.dart';

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
@riverpod
int customerBookingsNeedingMeCount(Ref ref) {
  final unread =
      ref.watch(unreadNotificationTargetsProvider).value ?? const <String>{};

  // Either target counts: an order is pointed at both as itself and as the job waiting to be
  // rated, and a rating invitation is exactly what the badge is for.
  bool unseen(Booking b) => UnreadNotificationTargets.bookingTargets.any(
    (target) => unread.contains(UnreadNotificationTargets.keyFor(target, b.id)),
  );

  return (ref.watch(customerBookingsProvider).value ?? const <Booking>[])
      .where((b) => bookingNeedsCustomer(b) && unseen(b))
      .length;
}

/// Whether one order is waiting on the customer. Separate so it can be tested on its own.
bool bookingNeedsCustomer(Booking booking) =>
    !booking.isCancelled &&
    (booking.needsMyReply(viewerIsBusiness: false) || booking.canBeRated);

@riverpod
class CustomerBookingsNotifier extends _$CustomerBookingsNotifier {
  @override
  Future<List<Booking>> build() =>
      ref.watch(bookingRepositoryProvider).getMyBookingsAsCustomer();

  Future<void> createBooking({
    required String businessServiceId,
    String? businessServiceVariantId,
    required DateTime scheduledDate,
    String? notes,
    required String addressLine1,
    String? addressLine2,
    required String city,
    required String state,
    required String postalCode,
    required double latitude,
    required double longitude,
    Map<String, String> answers = const {},
  }) async {
    final repository = ref.read(bookingRepositoryProvider);
    await repository.createBooking(
      businessServiceId: businessServiceId,
      businessServiceVariantId: businessServiceVariantId,
      scheduledDate: scheduledDate,
      notes: notes,
      addressLine1: addressLine1,
      addressLine2: addressLine2,
      city: city,
      state: state,
      postalCode: postalCode,
      latitude: latitude,
      longitude: longitude,
      answers: answers,
    );
    await _refresh(repository);
  }

  /// Counters the business's offer with the customer's own number.
  Future<void> proposeTerms(
    String bookingId, {
    required int workerCount,
    required double price,
    String? message,
  }) async {
    final repository = ref.read(bookingRepositoryProvider);
    await repository.proposeTerms(
      bookingId,
      asBusiness: false,
      workerCount: workerCount,
      price: price,
      message: message,
    );
    await _refresh(repository);
  }

  /// Takes up the business's offer, which confirms the order.
  Future<void> acceptTerms(String bookingId, String proposalId) async {
    final repository = ref.read(bookingRepositoryProvider);
    await repository.acceptTerms(bookingId, proposalId, asBusiness: false);
    await _refresh(repository);
  }

  Future<void> cancel(String id, {String? reason}) async {
    final repository = ref.read(bookingRepositoryProvider);
    await repository.cancelBookingAsCustomer(id, reason: reason);
    await _refresh(repository);
  }

  Future<void> rate(String id, {required int score, String? comment}) async {
    final repository = ref.read(bookingRepositoryProvider);
    await repository.rateBooking(id, score: score, comment: comment);
    await _refresh(repository);
  }

  /// Reloads the list, unless this notifier did not survive the request that preceded it.
  ///
  /// Takes the repository as an argument rather than reading it: by the time this runs, `ref` may be
  /// disposed, and reading through it is what threw the error this guard exists for.
  /// Re-reads the orders without a spinner, for the periodic check behind the Bookings tab count.
  /// A failed check keeps what is on screen.
  Future<void> refreshQuietly() async {
    final repository = ref.read(bookingRepositoryProvider);
    final result = await AsyncValue.guard<List<Booking>>(
      repository.getMyBookingsAsCustomer,
    );
    if (!ref.mounted || result.hasError) return;
    state = result;
  }

  Future<void> _refresh(BookingRepository repository) async {
    // Nothing is lost by stopping here. State on a disposed provider is unreachable, and the next
    // widget to watch this builds a fresh instance that fetches.
    if (!ref.mounted) return;

    state = const AsyncLoading();
    final result = await AsyncValue.guard<List<Booking>>(
      repository.getMyBookingsAsCustomer,
    );

    // Checked again: the fetch is another await, and the screen can leave during it.
    if (!ref.mounted) return;
    state = result;
  }
}
