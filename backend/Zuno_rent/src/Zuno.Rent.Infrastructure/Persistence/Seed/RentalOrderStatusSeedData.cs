using Zuno.Rent.Domain.Entities;
using Zuno.Rent.Domain.Enums;

namespace Zuno.Rent.Infrastructure.Persistence.Seed;

/// <summary>
/// Rent order statuses as the app shows them — which ones mean the pieces are promised (booked) or
/// with the customer (out) — and the steps a business may take between them.
/// </summary>
public static class RentalOrderStatusSeedData
{
    public static RentalOrderStatusOption[] Options =>
    [
        new() { Code = RentalOrderStatus.Booked, Name = "Booked", Tone = "progress", CountsAsBooked = true, DisplayOrder = 1 },
        new() { Code = RentalOrderStatus.OnRent, Name = "On rent", Tone = "danger", CountsAsOut = true, DisplayOrder = 2 },
        new() { Code = RentalOrderStatus.Returned, Name = "Returned", Tone = "success", DisplayOrder = 3 },
        new() { Code = RentalOrderStatus.Cancelled, Name = "Cancelled", Tone = "waiting", DisplayOrder = 4 },
        new() { Code = RentalOrderStatus.AwaitingAdvance, Name = "Awaiting advance", Tone = "waiting", CountsAsBooked = true, DisplayOrder = 5 },
    ];

    public static RentalOrderEventKindOption[] EventKinds =>
    [
        new() { Code = RentalOrderEventKind.Booked, Name = "Booked" },
        new() { Code = RentalOrderEventKind.StatusChanged, Name = "Status changed" },
        new() { Code = RentalOrderEventKind.AddOnAdded, Name = "Extra pieces added" },
        new() { Code = RentalOrderEventKind.BookedByCustomer, Name = "Booked by customer" },
        new() { Code = RentalOrderEventKind.AdvancePaid, Name = "Advance paid" },
        new() { Code = RentalOrderEventKind.PaymentReceived, Name = "Payment received" },
        new() { Code = RentalOrderEventKind.Refunded, Name = "Refunded" },
        new() { Code = RentalOrderEventKind.AdvanceLapsed, Name = "Advance not paid in time" },
        new() { Code = RentalOrderEventKind.CancellationCharged, Name = "Cancellation charge" },
        new() { Code = RentalOrderEventKind.RefundModeChosen, Name = "Refund method chosen" },
    ];

    public static RentalHomeSection[] HomeSections =>
    [
        new() { Code = "popular", Title = "Popular near you", Layout = RentalHomeLayout.Strip, Size = 10, ByPopularity = true, DisplayOrder = 1 },
        new() { Code = "explore", Title = "Explore", Layout = RentalHomeLayout.Grid, Size = 6, DisplayOrder = 2 },
        new() { Code = "more", Title = "More to rent", Layout = RentalHomeLayout.Strip, Size = 10, DisplayOrder = 3 },
        new() { Code = "all", Title = "All rentals", Layout = RentalHomeLayout.Grid, Size = 20, DisplayOrder = 4 },
    ];

    public static RentalOrderTransition[] Transitions =>
    [
        new() { FromStatus = RentalOrderStatus.Booked, ToStatus = RentalOrderStatus.OnRent, ActionLabel = "Send out", DisplayOrder = 1 },
        new() { FromStatus = RentalOrderStatus.Booked, ToStatus = RentalOrderStatus.Cancelled, ActionLabel = "Cancel order", ConfirmFirst = true, CustomerMay = true, DisplayOrder = 2 },
        new() { FromStatus = RentalOrderStatus.OnRent, ToStatus = RentalOrderStatus.Returned, ActionLabel = "Mark returned", RequiresPaid = true, DisplayOrder = 1 },
        new() { FromStatus = RentalOrderStatus.AwaitingAdvance, ToStatus = RentalOrderStatus.Cancelled, ActionLabel = "Cancel order", ConfirmFirst = true, CustomerMay = true, DisplayOrder = 1 },
    ];
}
