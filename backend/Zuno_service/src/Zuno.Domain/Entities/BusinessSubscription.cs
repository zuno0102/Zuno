using Zuno.Domain.Common;
using Zuno.Domain.Enums;

namespace Zuno.Domain.Entities;

/// <summary>
/// One purchase of a paid plan by a business. It keeps the plan's terms as they were when paid for
/// (price, days, areas), so a later price or area change by the Super Admin never alters it.
/// </summary>
public class BusinessSubscription : BaseEntity
{
    /// <summary>The business owner's user id — the key Rent and Marketplace use too.</summary>
    public Guid OwnerUserId { get; set; }

    public Guid PlanId { get; set; }

    public SubscriptionPlan Plan { get; set; } = null!;

    public string PlanName { get; set; } = string.Empty;

    public decimal Amount { get; set; }

    public int DurationDays { get; set; }

    public bool IncludesService { get; set; }

    public bool IncludesRent { get; set; }

    public bool IncludesMarketplace { get; set; }

    public SubscriptionStatus State { get; set; } = SubscriptionStatus.AwaitingPayment;

    /// <summary>Set when paid: now, or the end of the same plan still running (a renewal adds on).</summary>
    public DateTimeOffset? StartsAt { get; set; }

    public DateTimeOffset? EndsAt { get; set; }

    /// <summary>The Razorpay order raised for it; empty when collection is simulated.</summary>
    public string? PendingOrderId { get; set; }

    public string? PaymentId { get; set; }

    public DateTimeOffset? PaidAt { get; set; }

    /// <summary>The idempotency key for the payment order, so a retried start never charges twice.</summary>
    public string PaymentKey => $"plan{Id:N}";

    public bool Includes(ListingArea area) => area switch
    {
        ListingArea.Service => IncludesService,
        ListingArea.Rent => IncludesRent,
        ListingArea.Marketplace => IncludesMarketplace,
        _ => false,
    };

    /// <summary>Paid and running at <paramref name="now"/>.</summary>
    public bool IsRunning(DateTimeOffset now) =>
        State == SubscriptionStatus.Active && StartsAt <= now && EndsAt > now;

    /// <summary>Copies the plan's terms now, before payment; a price edit later does not change this purchase.</summary>
    public static BusinessSubscription Start(Guid ownerUserId, SubscriptionPlan plan) => new()
    {
        OwnerUserId = ownerUserId,
        PlanId = plan.Id,
        PlanName = plan.Name,
        Amount = plan.Price,
        DurationDays = plan.DurationDays ?? 0,
        IncludesService = plan.IncludesService,
        IncludesRent = plan.IncludesRent,
        IncludesMarketplace = plan.IncludesMarketplace,
    };

    /// <summary>Records the payment and runs the plan from <paramref name="from"/> for its days.</summary>
    public void Activate(string? paymentId, DateTimeOffset now, DateTimeOffset from)
    {
        PaymentId = paymentId;
        PaidAt = now;
        PendingOrderId = null;
        State = SubscriptionStatus.Active;
        StartsAt = from;
        EndsAt = from.AddDays(DurationDays);
    }
}

/// <summary>
/// A listing the end of a plan paused, so a renewal brings back exactly these and nothing the
/// business paused by itself.
/// </summary>
public class PlanPausedListing : BaseEntity
{
    public Guid OwnerUserId { get; set; }

    public ListingArea Area { get; set; }

    /// <summary>The listing's id in its own API (a service, rent item or Marketplace post).</summary>
    public Guid ListingId { get; set; }

    public DateTimeOffset PausedAt { get; set; }
}
