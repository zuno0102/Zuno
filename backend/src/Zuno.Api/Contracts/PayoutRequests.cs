namespace Zuno.Api.Contracts;

/// <summary>
/// Body for "Pay all". Optional, and never the source of the amount.
/// </summary>
/// <param name="ExpectedTotal">
/// What the app believes is owed. Sent only so a disagreement with the server's own figure can be
/// caught and refused — the server never pays this number.
/// </param>
public record CreatePayoutBatchRequest(decimal? ExpectedTotal);

/// <param name="ProviderPaymentId">
/// The payment provider's id for the collection. Doubles as the idempotency key, so the same
/// payment confirmed twice funds the run once.
/// </param>
/// <param name="Signature">Razorpay signature over the order and payment ids, verified server-side.</param>
public record ConfirmPayoutCollectionRequest(string ProviderPaymentId, string? Signature);

/// <param name="Received">True if the wages arrived; false raises a dispute against the business.</param>
public record RespondToPaymentRequest(bool Received, string? DisputeReason);
