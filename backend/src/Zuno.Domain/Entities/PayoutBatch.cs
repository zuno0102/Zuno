using Zuno.Domain.Common;
using Zuno.Domain.Enums;

namespace Zuno.Domain.Entities;

/// <summary>
/// One "pay the whole crew" action: a single amount collected from the business, then split out to
/// each worker.
/// </summary>
/// <remarks>
/// Two legs, because UPI cannot pay five people from one PIN. The business pays the total once
/// (collection), and the provider then sends each worker their share (disbursement). Recording them
/// separately is what makes a partial failure — money taken, one worker unpaid — visible and fixable
/// rather than silently lost.
/// </remarks>
public class PayoutBatch : BaseEntity
{
    public Guid HiringPostId { get; set; }

    public HiringPost HiringPost { get; set; } = null!;

    public Guid BusinessOwnerProfileId { get; set; }

    public BusinessOwnerProfile BusinessOwnerProfile { get; set; } = null!;

    /// <summary>The sum of every item. What the business is asked to pay in one go.</summary>
    public decimal TotalAmount { get; set; }

    public PayoutBatchStatus BatchStatus { get; set; } = PayoutBatchStatus.AwaitingCollection;

    /// <summary>The provider's order for the collection leg.</summary>
    public string? ProviderOrderId { get; set; }

    /// <summary>The provider's payment id once the business has actually paid.</summary>
    public string? ProviderPaymentId { get; set; }

    public DateTimeOffset? FundedAt { get; set; }

    public DateTimeOffset? CompletedAt { get; set; }

    /// <summary>
    /// Sent with every provider call for this batch. A double-tapped button must never pay twice,
    /// and this is what guarantees it.
    /// </summary>
    public string IdempotencyKey { get; set; } = Guid.NewGuid().ToString("N");

    public ICollection<PayoutBatchItem> Items { get; set; } = new List<PayoutBatchItem>();

    public decimal PaidAmount => Items
        .Where(i => i.PaymentStatus == PaymentStatus.Paid)
        .Sum(i => i.Amount);

    public bool AllItemsPaid => Items.Count > 0 && Items.All(i => i.PaymentStatus == PaymentStatus.Paid);

    public bool HasFailures => Items.Any(i => i.PaymentStatus == PaymentStatus.Failed);

    /// <summary>
    /// Whether this run pays the same workers the same amounts as <paramref name="other"/>.
    /// False once a salary has been raised since this run was opened.
    /// </summary>
    public bool PaysSameWagesAs(PayoutBatch other) =>
        Items.Count == other.Items.Count
        && Items
            .Select(i => (i.HiringPostApplicationId, i.Amount))
            .ToHashSet()
            .SetEquals(other.Items.Select(i => (i.HiringPostApplicationId, i.Amount)));
}
