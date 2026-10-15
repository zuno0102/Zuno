namespace Zuno.Domain.Enums;

/// <summary>
/// How far along staffing an order is — a separate question from where the order itself has got to.
/// </summary>
/// <remarks>
/// Kept apart from <see cref="BookingStatus"/> on purpose. The two used to share one field, so
/// assigning a worker overwrote "Confirmed" and a business could no longer tell an order it had
/// accepted from one it had not. Crew progress is derived from the assignments rather than stored,
/// so it cannot drift from them.
/// </remarks>
public enum BookingCrewStatus : short
{
    /// <summary>Nobody on it yet.</summary>
    NotStaffed = 1,

    /// <summary>Some of the crew is in place, but fewer than the job needs.</summary>
    PartStaffed = 2,

    /// <summary>The full crew is in place.</summary>
    FullyStaffed = 3,

    /// <summary>Everyone who was on it has finished their part.</summary>
    Done = 4,
}
