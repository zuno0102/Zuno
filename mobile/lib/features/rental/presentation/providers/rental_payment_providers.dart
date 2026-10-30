import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:zuno/core/payments/razorpay_checkout.dart';
import 'package:zuno/features/rental/domain/entities/rental_payment.dart';
import 'package:zuno/features/rental/presentation/providers/rental_providers.dart';

part 'rental_payment_providers.g.dart';

/// The words for advances and payment methods, from the server's tables. Read once per session.
@Riverpod(keepAlive: true)
Future<RentalPaymentOptions> rentalPaymentOptions(Ref ref) =>
    ref.watch(rentalRepositoryProvider).getPaymentOptions();

/// The business's UPI ID — what its order QR is made from. Null until it is set.
@riverpod
Future<String?> rentalUpiId(Ref ref) =>
    ref.watch(rentalRepositoryProvider).getUpiId();

/// Opens the payment window for a checkout and resolves with what it returns, or throws
/// [RazorpayCancelled]. A provider, so tests answer it without a payment SDK.
typedef RentalPaymentWindow =
    Future<RazorpayResult> Function(RentalCheckout checkout, String payee);

@Riverpod(keepAlive: true)
RentalPaymentWindow rentalPaymentWindow(Ref ref) =>
    (checkout, payee) => RazorpayCheckout.open(
      keyId: checkout.keyId,
      orderId: checkout.providerOrderId,
      amount: checkout.amount,
      description: checkout.description,
      businessName: payee,
    );
