using Zuno.Domain.Common;
using Zuno.Domain.Enums;

namespace Zuno.Domain.Entities;

/// <summary>
/// Where a worker's wages should be sent. Held apart from <see cref="WorkerProfile"/> because it is
/// money-routing data with its own verification life cycle — a worker can be perfectly valid while
/// their bank details are still unverified, and only verified details may be paid to.
/// </summary>
public class WorkerPayoutDetail : BaseEntity
{
    public Guid WorkerProfileId { get; set; }

    public WorkerProfile WorkerProfile { get; set; } = null!;

    /// <summary>UPI address, e.g. "ravi@okhdfcbank". The usual way to be paid in this market.</summary>
    public string? UpiVpa { get; set; }

    /// <summary>Bank details, for workers without UPI.</summary>
    public string? AccountNumber { get; set; }

    public string? IfscCode { get; set; }

    public string? AccountHolderName { get; set; }

    public VerificationStatus VerificationStatus { get; set; } = VerificationStatus.Pending;

    public DateTimeOffset? VerifiedAt { get; set; }

    /// <summary>
    /// The provider's own handle for this destination, created once and reused. Null until the
    /// details have been registered with the provider.
    /// </summary>
    public string? ProviderFundAccountId { get; set; }

    /// <summary>Whether there is anywhere to actually send money.</summary>
    public bool HasDestination =>
        !string.IsNullOrWhiteSpace(UpiVpa)
        || (!string.IsNullOrWhiteSpace(AccountNumber) && !string.IsNullOrWhiteSpace(IfscCode));

    /// <summary>
    /// Only verified details may be paid through the app. Anyone else has to be settled by hand,
    /// which the business must be told before it commits to a batch.
    /// </summary>
    public bool CanReceivePayouts =>
        HasDestination && VerificationStatus == VerificationStatus.Verified;
}
