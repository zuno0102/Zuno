using Zuno.Domain.Entities;
using Zuno.Domain.Enums;
using Zuno.Domain.ValueObjects;

namespace Zuno.Domain.Specifications;

/// <summary>
/// Which <see cref="OrderStage"/> a customer order or an own event is in. Decided here, once, so
/// every app shows the same stage for the same work instead of each working it out for itself.
/// </summary>
public static class OrderStages
{
    /// <summary>A worker's own wage that has not reached them yet.</summary>
    private static readonly PaymentStatus[] Outstanding =
    [
        PaymentStatus.Unpaid,
        PaymentStatus.Processing,
        PaymentStatus.Failed,
        PaymentStatus.AwaitingWorkerConfirmation,
    ];

    /// <summary>A customer order, as the person asking sees it.</summary>
    /// <param name="myAssignment">
    /// The viewing worker's own row on the order, when a worker is asking.
    /// </param>
    /// <param name="wages">
    /// The crew's wages, when the business is asking. Null for anyone it was not loaded for.
    /// </param>
    /// <remarks>
    /// "Completed or Awaiting payment" turns on who asks, because each viewer holds different facts:
    /// a worker knows their own wage, a business knows the whole crew's, and a customer knows neither
    /// — so a customer is simply told the work is done. Reading "not told about wages" as "wages are
    /// owed" once marked every finished job Awaiting payment on screens that could not know.
    /// </remarks>
    public static OrderStage ForBooking(
        BookingStatus status,
        BookingWorkerAssignment? myAssignment = null,
        BookingWageRollup? wages = null) => status switch
        {
            BookingStatus.Pending => OrderStage.Active,
            // Assigned is the older way of saying confirmed, with crew on it.
            BookingStatus.Confirmed or BookingStatus.Assigned => OrderStage.Confirmed,
            BookingStatus.InProgress => OrderStage.InProgress,
            BookingStatus.Cancelled => OrderStage.Cancelled,
            _ => CompletedStage(myAssignment, wages),
        };

    /// <summary>One of the business's own events, run through a hiring post with no order.</summary>
    public static OrderStage ForOwnEvent(HiringPost post) => post switch
    {
        { IsFullyComplete: true } => OrderStage.Completed,
        { WorkCompletedAt: not null } => OrderStage.AwaitingPayment,
        { WorkStartedAt: not null } => OrderStage.InProgress,
        // Planned and on the books, like a confirmed order.
        _ => OrderStage.Confirmed,
    };

    private static OrderStage CompletedStage(
        BookingWorkerAssignment? myAssignment,
        BookingWageRollup? wages)
    {
        if (myAssignment is not null)
        {
            // An amount as well as a status: a mirror row from a hiring post sits at Unpaid for ever
            // with no money on it, and reading that as owed is how paid jobs came to look unpaid.
            var owed = myAssignment.AgreedSalaryAmount is > 0
                && Outstanding.Contains(myAssignment.PaymentStatus);
            return owed ? OrderStage.AwaitingPayment : OrderStage.Completed;
        }

        return wages is { IsWageClear: false } ? OrderStage.AwaitingPayment : OrderStage.Completed;
    }
}
