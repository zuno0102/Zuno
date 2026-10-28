using Zuno.Domain.Enums;

namespace Zuno.Application.Modules.Business.Queries.GetBusinessDashboard;

/// <summary>Which dashboard tile an order counts under.</summary>
public enum DashboardOrderStage
{
    /// <summary>Not on any tile: waiting for the business to confirm, or happening today.</summary>
    None,

    /// <summary>Confirmed and its date still ahead.</summary>
    Upcoming,

    /// <summary>Work marked complete, but somebody on the crew is still unpaid.</summary>
    AwaitingPayment,

    /// <summary>Event, crew, work and payment all done.</summary>
    Finished,

    Cancelled,
}

/// <summary>
/// Sorts an order onto exactly one of the business dashboard's tiles.
/// </summary>
/// <remarks>
/// <para>
/// <b>Upcoming</b> is confirmed work only. A customer's request the business has not accepted yet
/// is not something on the books, and an order whose day has arrived is under way, not upcoming.
/// </para>
/// <para>
/// <b>Finished</b> means the whole order is closed — the same rule that credits the business's
/// record (<see cref="Zuno.Domain.Specifications.BookingWageRules.CountsAsCompleted"/>). Work marked
/// complete while a worker is still owed sits under <b>Awaiting payment</b> until they are paid,
/// so the two tiles never count the same order.
/// </para>
/// </remarks>
public static class DashboardOrderStages
{
    public static DashboardOrderStage Of(
        BookingStatus status,
        DateTimeOffset scheduledDate,
        bool isSettled,
        DateTimeOffset now) => status switch
        {
            BookingStatus.Cancelled => DashboardOrderStage.Cancelled,
            BookingStatus.Completed => isSettled
                ? DashboardOrderStage.Finished
                : DashboardOrderStage.AwaitingPayment,
            BookingStatus.Confirmed or BookingStatus.Assigned when scheduledDate > now
                => DashboardOrderStage.Upcoming,
            _ => DashboardOrderStage.None,
        };
}
