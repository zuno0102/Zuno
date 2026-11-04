import 'package:zuno/features/booking/domain/entities/booking_message.dart';
import 'package:zuno/features/rental/domain/entities/rental_payment.dart';
import 'package:zuno/features/rental/domain/entities/rental_stock.dart';

/// A rent order's shared screens — the list, the page, its history, the chat — as one side sees
/// them. The business and the customer each have one; the screens never ask which.
abstract class RentalOrdersGateway {
  /// This side's orders, newest first; one status only when [status] is given.
  Future<List<RentalOrder>> orders({String? status});

  Future<RentalOrder> order(String id);

  Future<List<RentalOrderEvent>> history(String id);

  /// What cancelling now would cost this side and give back.
  Future<RentalCancelQuote> cancelQuote(String id);

  /// One step from the order's actions — the business sends out; a customer cancels.
  /// [refundMode] is how the money goes back when the business cancels a paid order.
  Future<RentalOrder> takeStep(
    String id,
    String toStatus, {
    String? refundMode,
  });

  Future<List<RentalOrderThread>> threads();

  /// Oldest first; reading marks the other side's messages read.
  Future<List<BookingMessage>> messages(String id);

  Future<BookingMessage> send(String id, String body);
}
