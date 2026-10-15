namespace Zuno.Domain.ValueObjects;

/// <summary>
/// One worker's whole record across the app: what they have earned, what is owed, and how much
/// work they have actually done.
/// </summary>
/// <remarks>
/// <para>
/// A worker reaches paid work by two routes, and the two have to be added up differently — which is
/// the single thing to understand about this type.
/// </para>
/// <para>
/// <strong>Money never duplicates.</strong> The wage for a worker hired through a post lives on the
/// <c>HiringPostApplication</c>, and the mirror <c>BookingWorkerAssignment</c> created when they
/// accept is written without one. So amounts can be summed straight across both tables.
/// </para>
/// <para>
/// <strong>Job counts do duplicate.</strong> That same worker has an application *and* an
/// assignment for one job, so counting both would credit them twice. Counts are therefore
/// partitioned the way <c>BookingWageRules</c> partitions them for a business: the assignment is
/// what counts a job attached to an order, and an application counts on its own only for a
/// standalone post, which has no order behind it to count through.
/// </para>
/// </remarks>
/// <param name="TotalEarned">Wages actually received, by either route.</param>
/// <param name="OwedToYou">
/// Agreed wages on finished work that has not arrived. Post wages only: nothing in the app can yet
/// move a hand-assigned wage off Unpaid, so including those would show a worker a figure that could
/// never clear.
/// </param>
/// <param name="JobsCompleted">Jobs whose work is finished, counted once each.</param>
/// <param name="JobsPaid">How many wages have been received.</param>
/// <param name="AverageSalary">Average received wage, or null before the first one.</param>
/// <param name="BusinessesWorkedFor">Distinct businesses that have hired them.</param>
/// <param name="OffersDeclined">Offers they turned down. Post route only — the only route that has them.</param>
/// <param name="OpenDisputes">Times they reported wages never arrived, still unresolved.</param>
public readonly record struct WorkerEarningsRollup(
    decimal TotalEarned,
    decimal OwedToYou,
    int JobsCompleted,
    int JobsPaid,
    decimal? AverageSalary,
    int BusinessesWorkedFor,
    int OffersDeclined,
    int OpenDisputes)
{
    /// <summary>Nothing has been earned and nothing is owed, so a zero state can be shown instead of ₹0.</summary>
    public bool HasWorkRecord => JobsCompleted > 0 || TotalEarned > 0m;

    /// <summary>Money is late: the work is done and has not been paid for.</summary>
    public bool IsOwedMoney => OwedToYou > 0m;
}
