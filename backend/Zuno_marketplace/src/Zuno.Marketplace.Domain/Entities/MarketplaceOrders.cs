using Zuno.Marketplace.Domain.Common;
using Zuno.Marketplace.Domain.Enums;

namespace Zuno.Marketplace.Domain.Entities;

/// <summary>
/// A customer's order of a product: what was bought, how it is paid, and where it is on its way.
/// What the customer saw is copied in — the title, the colour / size, the price — so a later edit of
/// the post never changes an order already made.
/// </summary>
public class MarketplaceOrder : BaseEntity
{
    public Guid PostId { get; set; }

    public MarketplacePost Post { get; set; } = null!;

    /// <summary>The colour / size bought; null on a product without any.</summary>
    public Guid? VariantId { get; set; }

    /// <summary>The business that sells it.</summary>
    public Guid OwnerUserId { get; set; }

    public Guid CustomerUserId { get; set; }

    public string CustomerName { get; set; } = string.Empty;

    public string CustomerPhone { get; set; } = string.Empty;

    public string DeliveryAddress { get; set; } = string.Empty;

    public string Pincode { get; set; } = string.Empty;

    public string Title { get; set; } = string.Empty;

    /// <summary>"Red · M"; null without a colour / size.</summary>
    public string? VariantName { get; set; }

    public int Quantity { get; set; }

    public decimal UnitPrice { get; set; }

    public decimal Amount { get; set; }

    public MarketplacePaymentMethod PaymentMethod { get; set; }

    public MarketplaceOrderStatus Status { get; set; }

    /// <summary>An online order not paid by then is let go and its stock goes back.</summary>
    public DateTimeOffset? PayBy { get; set; }

    /// <summary>When the money came in: online once the payment is proven, cash when delivered.</summary>
    public DateTimeOffset? PaidAt { get; set; }

    /// <summary>The gateway's order the customer pays against.</summary>
    public string? ProviderOrderId { get; set; }

    public string? ProviderPaymentId { get; set; }

    /// <summary>A paid online order that was cancelled: the money must go back.</summary>
    public bool RefundDue { get; set; }

    /// <summary>The gateway's refund, once made.</summary>
    public string? RefundId { get; set; }

    /// <summary>The courier row it went with — "dtdc", or "other" with its own <see cref="CourierName"/>.</summary>
    public string? CourierCode { get; set; }

    public string? CourierName { get; set; }

    public string? TrackingNumber { get; set; }

    /// <summary>A photo of the courier's receipt, if the business added one.</summary>
    public string? ReceiptUrl { get; set; }

    public DateTimeOffset? ShippedAt { get; set; }

    public DateTimeOffset? DeliveredAt { get; set; }

    /// <summary>A delivered order with no review closes by itself at this time.</summary>
    public DateTimeOffset? ClosesAt { get; set; }

    public DateTimeOffset? ClosedAt { get; set; }

    public DateTimeOffset? CancelledAt { get; set; }

    public MarketplaceOrderActor? CancelledBy { get; set; }

    /// <summary>The customer's stars, 1 to 5; null until reviewed.</summary>
    public short? RatingScore { get; set; }

    public string? RatingComment { get; set; }

    public DateTimeOffset? RatedAt { get; set; }

    public ICollection<MarketplaceOrderEvent> Events { get; set; } = new List<MarketplaceOrderEvent>();

    /// <summary>Paid online and not given back: what Zuno owes the business for it.</summary>
    public decimal DueToBusiness =>
        PaymentMethod == MarketplacePaymentMethod.Online && PaidAt is not null && Status != MarketplaceOrderStatus.Cancelled
            ? Amount
            : 0m;

    /// <summary>Moves the order on and writes the step into its history.</summary>
    public MarketplaceOrderEvent MoveTo(
        MarketplaceOrderStatus status, MarketplaceOrderActor actor, Guid? actorUserId, DateTimeOffset now, string? note = null)
    {
        Status = status;
        var step = new MarketplaceOrderEvent
        {
            OrderId = Id,
            Status = status,
            Actor = actor,
            ActorUserId = actorUserId,
            Note = note,
            At = now,
        };
        Events.Add(step);
        return step;
    }
}

/// <summary>One step in an order's history: "Shipped by the business, 16 Nov". Only ever added.</summary>
public class MarketplaceOrderEvent : BaseEntity
{
    public Guid OrderId { get; set; }

    public MarketplaceOrderStatus Status { get; set; }

    public MarketplaceOrderActor Actor { get; set; }

    public Guid? ActorUserId { get; set; }

    /// <summary>E.g. "DTDC · D45120098871" on the shipped step.</summary>
    public string? Note { get; set; }

    public DateTimeOffset At { get; set; }
}

/// <summary>How an order status is named and coloured. Keyed by the enum.</summary>
public class MarketplaceOrderStatusOption
{
    public MarketplaceOrderStatus Code { get; set; }

    public string Name { get; set; } = string.Empty;

    /// <summary>The app's status colour: <c>success</c>, <c>progress</c>, <c>waiting</c> or <c>danger</c>.</summary>
    public string Tone { get; set; } = "waiting";

    public short DisplayOrder { get; set; }

    /// <summary>The name the customer sees when it differs from the business's — "Ordered" for New. Null uses <see cref="Name"/>.</summary>
    public string? CustomerName { get; set; }

    /// <summary>The colour the customer sees when it differs — calm where the business's is a call to act. Null uses <see cref="Tone"/>.</summary>
    public string? CustomerTone { get; set; }

    /// <summary>The step of the customer's progress bar this status is at; null for one off the bar (Cancelled).</summary>
    public short? TrackStep { get; set; }

    public string NameFor(MarketplaceOrderActor viewer) =>
        viewer == MarketplaceOrderActor.Customer && !string.IsNullOrWhiteSpace(CustomerName) ? CustomerName : Name;

    public string ToneFor(MarketplaceOrderActor viewer) =>
        viewer == MarketplaceOrderActor.Customer && !string.IsNullOrWhiteSpace(CustomerTone) ? CustomerTone : Tone;
}

/// <summary>One step of the customer's order progress bar — Ordered, Confirmed, Shipped … — in order.</summary>
public class MarketplaceOrderTrackStep
{
    public short Code { get; set; }

    public string Name { get; set; } = string.Empty;

    public short DisplayOrder { get; set; }
}

/// <summary>
/// A step a business or customer may take on an order, e.g. Confirmed → Shipped is "Mark shipped" by
/// the business. The buttons are these rows; a step not here is refused.
/// </summary>
public class MarketplaceOrderTransition
{
    public MarketplaceOrderStatus FromStatus { get; set; }

    public MarketplaceOrderStatus ToStatus { get; set; }

    /// <summary>The button, e.g. "Mark shipped".</summary>
    public string ActionName { get; set; } = string.Empty;

    /// <summary>Ask "are you sure?" first.</summary>
    public bool NeedsConfirm { get; set; }

    public bool BusinessMay { get; set; }

    public bool CustomerMay { get; set; }

    /// <summary>Taken through the ship sheet: needs the courier and its tracking number.</summary>
    public bool NeedsTracking { get; set; }

    public short DisplayOrder { get; set; }

    public bool AllowedFor(MarketplaceOrderActor actor) => actor switch
    {
        MarketplaceOrderActor.Business => BusinessMay,
        MarketplaceOrderActor.Customer => CustomerMay,
        _ => false,
    };
}

/// <summary>
/// A courier a business can send with — India Post, DTDC — and, when it has one, the address its
/// tracking page opens at, with <c>{number}</c> where the tracking number goes.
/// </summary>
public class MarketplaceCourier
{
    public const string NumberToken = "{number}";

    /// <summary>E.g. <c>dtdc</c>.</summary>
    public string Code { get; set; } = string.Empty;

    public string Name { get; set; } = string.Empty;

    /// <summary>E.g. <c>https://www.delhivery.com/track/package/{number}</c>; null when there is none to link.</summary>
    public string? TrackingUrl { get; set; }

    /// <summary>"Other": the business types the courier's name itself.</summary>
    public bool TakesCustomName { get; set; }

    public bool IsActive { get; set; } = true;

    public short DisplayOrder { get; set; }

    /// <summary>The tracking page for <paramref name="trackingNumber"/>; null when the courier has none.</summary>
    public static string? TrackingLink(string? template, string? trackingNumber) =>
        string.IsNullOrWhiteSpace(template) || string.IsNullOrWhiteSpace(trackingNumber)
            ? null
            : template.Replace(NumberToken, Uri.EscapeDataString(trackingNumber), StringComparison.Ordinal);
}

/// <summary>How a payment method is named, with the line under it. Keyed by the enum.</summary>
public class MarketplacePaymentMethodOption
{
    public MarketplacePaymentMethod Code { get; set; }

    public string Name { get; set; } = string.Empty;

    public string Detail { get; set; } = string.Empty;

    public short DisplayOrder { get; set; }
}

/// <summary>
/// A buyer asking a seller for a B2B lot: how much, and a note. When the seller accepts, the two
/// talk directly; nothing more happens in the app. Each side's contact is copied in when they act.
/// </summary>
public class MarketplaceB2BRequest : BaseEntity
{
    public Guid PostId { get; set; }

    public MarketplacePost Post { get; set; } = null!;

    /// <summary>The seller.</summary>
    public Guid OwnerUserId { get; set; }

    public Guid BuyerUserId { get; set; }

    public string BuyerName { get; set; } = string.Empty;

    public string? BuyerPhone { get; set; }

    public string Title { get; set; } = string.Empty;

    /// <summary>In the post's unit, e.g. kg.</summary>
    public int Quantity { get; set; }

    public string? Unit { get; set; }

    /// <summary>The post's price per unit when asked.</summary>
    public decimal? UnitPrice { get; set; }

    public string? Message { get; set; }

    public MarketplaceB2BRequestStatus Status { get; set; } = MarketplaceB2BRequestStatus.Requested;

    public DateTimeOffset? RespondedAt { get; set; }

    /// <summary>The seller's business name and phone, copied in when they accept.</summary>
    public string? SellerName { get; set; }

    public string? SellerPhone { get; set; }
}

/// <summary>How a B2B request status is named and coloured. Keyed by the enum.</summary>
public class MarketplaceB2BRequestStatusOption
{
    public MarketplaceB2BRequestStatus Code { get; set; }

    public string Name { get; set; } = string.Empty;

    public string Tone { get; set; } = "waiting";

    public short DisplayOrder { get; set; }
}
