using Zuno.Domain.Common;
using Zuno.Domain.Enums;

namespace Zuno.Domain.Entities;

/// <summary>One worker's share of a <see cref="PayoutBatch"/>.</summary>
public class PayoutBatchItem : BaseEntity
{
    public Guid PayoutBatchId { get; set; }

    public PayoutBatch PayoutBatch { get; set; } = null!;

    /// <summary>The application this payment settles.</summary>
    public Guid? HiringPostApplicationId { get; set; }

    public HiringPostApplication? HiringPostApplication { get; set; }

    public Guid? WorkerProfileId { get; set; }

    public WorkerProfile? WorkerProfile { get; set; }

    /// <summary>Shown on the receipt and in failure messages, so a failed row is still identifiable.</summary>
    public string WorkerName { get; set; } = string.Empty;

    public decimal Amount { get; set; }

    public PaymentStatus PaymentStatus { get; set; } = PaymentStatus.Unpaid;

    public string? ProviderPayoutId { get; set; }

    /// <summary>The provider's reason, kept verbatim so a business can act on it.</summary>
    public string? FailureReason { get; set; }

    public DateTimeOffset? PaidAt { get; set; }
}
