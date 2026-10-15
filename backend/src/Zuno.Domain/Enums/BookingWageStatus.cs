namespace Zuno.Domain.Enums;

/// <summary>
/// Where the crew's wages for one order have got to — a separate question from whether the work is
/// done.
/// </summary>
/// <remarks>
/// Derived from the hiring posts raised against the order, never stored, for the same reason
/// <see cref="BookingCrewStatus"/> is: a stored copy drifts from the rows it summarises the first
/// time anything touches them out of band.
/// </remarks>
public enum BookingWageStatus : short
{
    /// <summary>
    /// Nobody is owed anything through the app. Either the crew came from the business's own
    /// roster and is paid offline, or a hiring post was raised that nobody accepted.
    /// </summary>
    /// <remarks>
    /// Deliberately not a kind of "pending". An order with no in-app wages has nothing that could
    /// ever be marked paid, so showing it as outstanding would leave it waiting on an event that
    /// is never coming.
    /// </remarks>
    NoWagesThroughZuno = 1,

    /// <summary>A worker says a wage never arrived. Outranks everything below it.</summary>
    Disputed = 2,

    /// <summary>At least one worker is still owed.</summary>
    Outstanding = 3,

    /// <summary>Every worker on this order has been paid.</summary>
    Settled = 4,
}
