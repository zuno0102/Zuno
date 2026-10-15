namespace Zuno.Application.Modules.Business.DTOs;

/// <summary>
/// What a business's record looks like to each side of the marketplace.
/// </summary>
/// <remarks>
/// Deliberately two blocks rather than one score. A customer is deciding whether the job will be
/// done well; a worker is deciding whether they will be paid, and how much. Those are different
/// questions and a single number answers neither honestly.
/// </remarks>
public class BusinessTrustDto
{
    public CustomerFacingTrustDto Customers { get; set; } = new();

    public WorkerFacingTrustDto Workers { get; set; } = new();
}

/// <summary>The delivery record — what a customer is buying.</summary>
public class CustomerFacingTrustDto
{
    /// <summary>Jobs where the work finished <em>and</em> every worker was paid.</summary>
    public int EventsCompleted { get; set; }

    /// <summary>Null until anyone has reviewed, which is different from a rating of zero.</summary>
    public decimal? RatingAverage { get; set; }

    public int ReviewCount { get; set; }

    /// <summary>Customers who booked this business more than once.</summary>
    public int RepeatCustomers { get; set; }
}

/// <summary>
/// The pay record — what a worker is deciding on. Salary leads, because that is what actually
/// brings someone to the job.
/// </summary>
public class WorkerFacingTrustDto
{
    /// <summary>Mean agreed wage across every hire. Null when nobody has been hired yet.</summary>
    public decimal? AverageSalary { get; set; }

    public decimal? LowestSalary { get; set; }

    public decimal? HighestSalary { get; set; }

    /// <summary>How the wage is quoted — PerEvent, PerDay, PerHour. The most common one used.</summary>
    public string? SalaryUnit { get; set; }

    public int TotalHires { get; set; }

    /// <summary>Hires where the agreed wage met or beat the rate advertised on the post.</summary>
    public int PaidPostedRateCount { get; set; }

    /// <summary>Hires where the business agreed to more than it advertised.</summary>
    public int RaisedPayCount { get; set; }

    /// <summary>Of the crew whose work is finished, how many have actually been paid.</summary>
    public int CrewsPaid { get; set; }

    public int CrewsAwaitingPayment { get; set; }

    /// <summary>
    /// Median hours between work finishing and money landing. A median, not a mean: one bad
    /// month should not outweigh a business that is reliably prompt.
    /// </summary>
    public decimal? TypicalHoursToPay { get; set; }

    /// <summary>Distinct workers hired, and how many hires between them — repeat crew is the
    /// strongest signal there is, because nobody returns to someone who did not pay them.</summary>
    public int DistinctWorkers { get; set; }

    public int RepeatHires { get; set; }

    /// <summary>Unresolved "I was never paid" reports. Surfaced to workers, and only as an alert
    /// to the business itself.</summary>
    public int OpenDisputes { get; set; }

    /// <summary>Wages still unpaid on work that is already finished.</summary>
    public decimal OverdueWages { get; set; }
}
