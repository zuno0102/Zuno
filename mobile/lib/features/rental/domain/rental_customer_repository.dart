import 'package:zuno/features/rental/domain/entities/rental_customer.dart';
import 'package:zuno/features/rental/domain/entities/rental_payment.dart';
import 'package:zuno/features/rental/domain/entities/rental_stock.dart';

/// Browsing and booking rent items, as the customer screens use them.
abstract class RentalCustomerRepository {
  /// The Rent home, shuffled by [seed]: the same seed is the same page, a new one a new mix.
  Future<List<RentalHomeSection>> home(int seed, List<String> districtIds);

  Future<List<RentalCard>> banners(List<String> districtIds);

  Future<List<RentalCard>> search({
    String? categoryId,
    String? keyword,
    List<String> districtIds = const [],
  });

  Future<RentalItemDetail> item(String id);

  Future<RentalAvailability> availability(
    String id,
    DateTime start,
    DateTime end,
  );

  /// Refused by the server when the dates do not leave enough, the district is outside the item's
  /// area, or a required question is unanswered — with words to show.
  Future<RentalOrder> book(RentalBookingInput input);

  /// The mobile the customer verified last, to start the booking form with; null when none.
  Future<String?> verifiedPhone();

  /// Sends a one-time code to [phone] — refused, with words to show, when asked again too soon.
  Future<RentalPhoneCodeSent> sendPhoneCode(String phone);

  /// Checks the code typed; refused, with words to show, when wrong or expired.
  Future<void> verifyPhoneCode(String phone, String code);

  /// Starts paying online: the advance while it is awaited, otherwise what is due.
  Future<RentalCheckout> checkout(String orderId);

  /// The payment window's answer; the server counts it only when its signature checks out.
  Future<RentalOrder> pay(
    String orderId, {
    required String providerOrderId,
    required String paymentId,
    required String signature,
  });

  /// Stars (1-5) and an optional comment for a returned, fully paid rental. Refused by the server,
  /// with words to show, when it is not ready to rate or was rated already.
  Future<RentalOrder> rate(String orderId, int score, {String? comment});
}
