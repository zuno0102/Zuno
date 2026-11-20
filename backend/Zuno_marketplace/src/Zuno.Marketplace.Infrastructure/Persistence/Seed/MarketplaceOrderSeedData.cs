using Zuno.Marketplace.Domain.Entities;
using Zuno.Marketplace.Domain.Enums;

namespace Zuno.Marketplace.Infrastructure.Persistence.Seed;

/// <summary>
/// The words, colours and steps of product orders and B2B requests, and the couriers a business can
/// send with. Rows, so a name, a colour, a courier or a tracking link changes without a release.
/// </summary>
public static class MarketplaceOrderSeedData
{
    /// <summary>
    /// Names and colours, and where each status sits on the customer's progress bar. The customer sees
    /// "Ordered" where the business sees "New"; Cancelled is off the bar.
    /// </summary>
    public static MarketplaceOrderStatusOption[] Statuses =>
    [
        new() { Code = MarketplaceOrderStatus.Placed, Name = "New", Tone = "danger", DisplayOrder = 1, CustomerName = "Ordered", CustomerTone = "progress", TrackStep = 1 },
        new() { Code = MarketplaceOrderStatus.AwaitingPayment, Name = "Awaiting payment", Tone = "waiting", DisplayOrder = 2, TrackStep = 1 },
        new() { Code = MarketplaceOrderStatus.Confirmed, Name = "Confirmed", Tone = "progress", DisplayOrder = 3, TrackStep = 2 },
        new() { Code = MarketplaceOrderStatus.Shipped, Name = "Shipped", Tone = "progress", DisplayOrder = 4, TrackStep = 3 },
        new() { Code = MarketplaceOrderStatus.OutForDelivery, Name = "Out for delivery", Tone = "progress", DisplayOrder = 5, TrackStep = 4 },
        new() { Code = MarketplaceOrderStatus.Delivered, Name = "Delivered", Tone = "success", DisplayOrder = 6, TrackStep = 5 },
        new() { Code = MarketplaceOrderStatus.Closed, Name = "Closed", Tone = "success", DisplayOrder = 7, CustomerName = "Completed", TrackStep = 5 },
        new() { Code = MarketplaceOrderStatus.Cancelled, Name = "Cancelled", Tone = "waiting", DisplayOrder = 8 },
    ];

    /// <summary>The customer's progress bar, left to right.</summary>
    public static MarketplaceOrderTrackStep[] TrackSteps =>
    [
        new() { Code = 1, Name = "Ordered", DisplayOrder = 1 },
        new() { Code = 2, Name = "Confirmed", DisplayOrder = 2 },
        new() { Code = 3, Name = "Shipped", DisplayOrder = 3 },
        new() { Code = 4, Name = "Out for delivery", DisplayOrder = 4 },
        new() { Code = 5, Name = "Delivered", DisplayOrder = 5 },
    ];

    /// <summary>
    /// The buttons. Paying online confirms an order, and a review or the days after delivery close it:
    /// those are not buttons, so they are not here. The customer cancels only before it ships.
    /// </summary>
    public static MarketplaceOrderTransition[] Transitions =>
    [
        Business(MarketplaceOrderStatus.Placed, MarketplaceOrderStatus.Confirmed, "Confirm order", 1),
        Business(MarketplaceOrderStatus.Confirmed, MarketplaceOrderStatus.Shipped, "Mark shipped", 2, needsTracking: true),
        Business(MarketplaceOrderStatus.Shipped, MarketplaceOrderStatus.OutForDelivery, "Out for delivery", 3),
        Business(MarketplaceOrderStatus.OutForDelivery, MarketplaceOrderStatus.Delivered, "Mark delivered", 4, needsConfirm: true),
        Business(MarketplaceOrderStatus.Shipped, MarketplaceOrderStatus.Delivered, "Mark delivered", 5, needsConfirm: true),
        Customer(MarketplaceOrderStatus.AwaitingPayment, MarketplaceOrderStatus.Cancelled, "Cancel order", 6),
        Customer(MarketplaceOrderStatus.Placed, MarketplaceOrderStatus.Cancelled, "Cancel order", 7),
        Customer(MarketplaceOrderStatus.Confirmed, MarketplaceOrderStatus.Cancelled, "Cancel order", 8),
    ];

    /// <summary>
    /// Couriers businesses here send with. A tracking link only where the courier's page takes the
    /// number in its address; for the rest the customer gets the number to type on the courier's site.
    /// </summary>
    public static MarketplaceCourier[] Couriers =>
    [
        new() { Code = "india-post", Name = "India Post", DisplayOrder = 1 },
        new() { Code = "dtdc", Name = "DTDC", DisplayOrder = 2 },
        new() { Code = "st-courier", Name = "ST Courier", DisplayOrder = 3 },
        new() { Code = "professional", Name = "The Professional Couriers", DisplayOrder = 4 },
        new() { Code = "delhivery", Name = "Delhivery", TrackingUrl = "https://www.delhivery.com/track/package/" + MarketplaceCourier.NumberToken, DisplayOrder = 5 },
        new() { Code = "blue-dart", Name = "Blue Dart", DisplayOrder = 6 },
        new() { Code = "other", Name = "Other", TakesCustomName = true, DisplayOrder = 99 },
    ];

    public static MarketplacePaymentMethodOption[] PaymentMethods =>
    [
        new()
        {
            Code = MarketplacePaymentMethod.CashOnDelivery,
            Name = "Cash on delivery",
            // Read by the business (payment settings) and the customer (Buy now) alike.
            Detail = "Paid in cash to the courier or the seller when it arrives.",
            DisplayOrder = 1,
        },
        new()
        {
            Code = MarketplacePaymentMethod.Online,
            Name = "Online pay",
            Detail = "UPI, cards and net banking. The order is confirmed only after the payment goes through.",
            DisplayOrder = 2,
        },
    ];

    public static MarketplaceB2BRequestStatusOption[] B2BRequestStatuses =>
    [
        new() { Code = MarketplaceB2BRequestStatus.Requested, Name = "New", Tone = "danger", DisplayOrder = 1 },
        new() { Code = MarketplaceB2BRequestStatus.Accepted, Name = "Accepted", Tone = "success", DisplayOrder = 2 },
        new() { Code = MarketplaceB2BRequestStatus.Declined, Name = "Declined", Tone = "waiting", DisplayOrder = 3 },
    ];

    private static MarketplaceOrderTransition Business(
        MarketplaceOrderStatus from, MarketplaceOrderStatus to, string action, short order, bool needsConfirm = false, bool needsTracking = false) =>
        new()
        {
            FromStatus = from,
            ToStatus = to,
            ActionName = action,
            BusinessMay = true,
            NeedsConfirm = needsConfirm,
            NeedsTracking = needsTracking,
            DisplayOrder = order,
        };

    private static MarketplaceOrderTransition Customer(MarketplaceOrderStatus from, MarketplaceOrderStatus to, string action, short order) =>
        new()
        {
            FromStatus = from,
            ToStatus = to,
            ActionName = action,
            CustomerMay = true,
            NeedsConfirm = true,
            DisplayOrder = order,
        };
}
