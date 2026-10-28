namespace Zuno.Application.Common.Interfaces;

/// <summary>An order for the business to pay the batch total in one go.</summary>
/// <param name="ProviderOrderId">Handed to the client to open the payment sheet.</param>
/// <param name="AmountPaise">The amount in the smallest currency unit, as providers expect.</param>
public record PayoutCollectionOrder(string ProviderOrderId, long AmountPaise);

/// <summary>The provider's immediate answer when asked to send one worker their share.</summary>
/// <param name="ProviderPayoutId">The provider's handle, used to match its later webhook.</param>
/// <param name="Accepted">
/// Whether the provider took the instruction. False means it was rejected outright — bad account
/// details, insufficient balance — and <paramref name="FailureReason"/> says why.
/// </param>
public record PayoutInstructionResult(string? ProviderPayoutId, bool Accepted, string? FailureReason);

/// <summary>
/// Moves money: collects one total from the business, then sends each worker their share.
/// </summary>
/// <remarks>
/// An interface for the same reason <c>IEmailService</c> is one — the provider is a detail, and the
/// whole flow has to be exercisable without a merchant account or real money. A fake implementation
/// runs in Development; the real provider is wired only in Production.
///
/// Nothing here moves a worker to Paid. Only a signature-verified webhook does that, because the
/// HTTP response to an instruction says the provider accepted it, not that the money arrived.
/// </remarks>
public interface IPayoutProvider
{
    /// <summary>Human-readable name of the provider in use, for logs and the admin screen.</summary>
    string Name { get; }

    /// <summary>
    /// Creates the order the business pays against — the single "₹1500, one PIN" step.
    /// </summary>
    /// <param name="idempotencyKey">
    /// The batch's key. Calling twice with the same key must yield the same order, never a second charge.
    /// </param>
    Task<PayoutCollectionOrder> CreateCollectionOrderAsync(
        decimal amount,
        string idempotencyKey,
        string description,
        CancellationToken cancellationToken = default);

    /// <summary>Instructs the provider to send one worker their share.</summary>
    /// <param name="destination">A UPI address, or bank details, already verified.</param>
    /// <param name="idempotencyKey">Unique per item, so a retry cannot pay the same worker twice.</param>
    Task<PayoutInstructionResult> CreatePayoutAsync(
        PayoutDestination destination,
        decimal amount,
        string idempotencyKey,
        string narration,
        CancellationToken cancellationToken = default);


    /// <summary>
    /// Whether a webhook really came from the provider. Anything failing this is discarded — an
    /// unauthenticated webhook could otherwise mark unpaid workers as paid.
    /// </summary>
    /// <summary>
    /// Whether a completed checkout really came from the provider.
    /// </summary>
    /// <remarks>
    /// The client reports its own payment as successful, so without this anyone could claim a
    /// pay run was funded and have workers marked paid without a rupee moving. The signature is
    /// computed with the key secret, which only the server holds.
    /// </remarks>
    bool VerifyPaymentSignature(string orderId, string paymentId, string signature);

}

/// <summary>Where one payout is going.</summary>
public record PayoutDestination(
    string WorkerName,
    string? UpiVpa,
    string? AccountNumber,
    string? IfscCode,
    string? ProviderFundAccountId);
