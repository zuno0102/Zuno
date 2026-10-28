namespace Zuno.Application.Modules.Worker.DTOs;

/// <summary>
/// A worker's home screen: what they have done, what they are owed, and what is coming.
/// </summary>
/// <remarks>
/// Carries the profile whole rather than beside it, so the screen has one source for the figures it
/// shows. Two endpoints each computing "total earned" is how the shell header and the profile tab
/// came to disagree about what a worker was owed.
/// </remarks>
public class WorkerDashboardDto
{
    /// <summary>Identity, skills, payout setup, and the work-record figures.</summary>
    public WorkerProfileDto Profile { get; set; } = new();

    // ---- Where the work has got to --------------------------------------------------------

    /// <summary>Jobs under way right now: started and not finished.</summary>
    public int InProgressCount { get; set; }

    /// <summary>Jobs still to come, whose day has not arrived.</summary>
    public int UpcomingCount { get; set; }

    /// <summary>
    /// Open jobs anywhere that this worker has not applied to yet.
    /// </summary>
    /// <remarks>
    /// Deliberately not filtered by distance, and deliberately not read off the job feed. The header
    /// carrying this number sits above every tab, so a figure shaped by a radius the worker chose on
    /// one tab would be wrong on the other three — and once a location is required to browse, a
    /// feed-derived count would read zero until one was set.
    /// </remarks>
    public int OpenHiringPostCount { get; set; }

    public List<WorkerJobSummaryDto> InProgress { get; set; } = [];

    public List<WorkerJobSummaryDto> Upcoming { get; set; } = [];

    /// <summary>
    /// Work already finished, most recent first.
    /// </summary>
    /// <remarks>
    /// Sent so the count on the dashboard can be opened rather than merely read. A worker who has done
    /// forty jobs wants to see which forty — and it is the only place the variant, the business and
    /// what they were paid appear together for past work.
    /// </remarks>
    public List<WorkerJobSummaryDto> Completed { get; set; } = [];

    // ---- Money still to come --------------------------------------------------------------

    /// <summary>
    /// Finished work that has not been paid for, one row per job, so a worker can see which job the
    /// money is stuck on rather than a single unexplained total.
    /// </summary>
    public List<WorkerPendingPaymentDto> PendingPayments { get; set; } = [];

    /// <summary>
    /// The same figure as <see cref="WorkerProfileDto.OwedToYou"/>, sent alongside the rows so a
    /// client never has to add them up and reach a different answer.
    /// </summary>
    public decimal PendingPaymentTotal { get; set; }

    /// <summary>Month by month, oldest first, including the quiet months.</summary>
    public List<WorkerMonthlyEarningDto> Trend { get; set; } = [];
}

/// <summary>One job on a worker's list, from whichever route put them on it.</summary>
public class WorkerJobSummaryDto
{
    /// <summary>The booking id, or the post id for standalone work.</summary>
    public Guid Id { get; set; }

    /// <summary>
    /// "Booking" or "Post". A standalone post has no order behind it, so the client cannot open it
    /// the same way and needs to be told which it is holding.
    /// </summary>
    public string Source { get; set; } = string.Empty;

    public string Title { get; set; } = string.Empty;

    public string BusinessName { get; set; } = string.Empty;

    public DateTimeOffset ScheduledDate { get; set; }

    public string? Location { get; set; }

    /// <summary>This worker's own wage, not the price the customer pays. Null when paid off app.</summary>
    public decimal? MyWage { get; set; }

    public string? MyWageUnit { get; set; }

    /// <summary>Where this worker stands on the job, not where the job stands.</summary>
    public string MyStatus { get; set; } = string.Empty;

    public DateTimeOffset? WorkStartedAt { get; set; }

    /// <summary>Whether the worker still has to say yes or no to this job.</summary>
    /// <summary>
    /// What this worker is on this job — Lead, Supervisor or Support — or null for a plain
    /// crew member.
    /// </summary>
    /// <remarks>
    /// Only an order can carry one: the three describe a place in a crew, and a hiring post is
    /// taken on alone. Always null on a post rather than invented.
    /// </remarks>
    public string? MyRole { get; set; }

    public bool NeedsMyAnswer { get; set; }
}

/// <summary>A wage that has been earned and not received.</summary>
public class WorkerPendingPaymentDto
{
    /// <summary>The application id, which is what the worker confirms or disputes against.</summary>
    public Guid ApplicationId { get; set; }

    public string Title { get; set; } = string.Empty;

    public string BusinessName { get; set; } = string.Empty;

    public decimal Amount { get; set; }

    public string? Unit { get; set; }

    public string PaymentStatus { get; set; } = string.Empty;

    public DateTimeOffset? WorkCompletedAt { get; set; }
}

/// <summary>One month of a worker's history.</summary>
public class WorkerMonthlyEarningDto
{
    public string Label { get; set; } = string.Empty;

    public int Year { get; set; }

    public int Month { get; set; }

    public int JobsCompleted { get; set; }

    public decimal Earned { get; set; }
}
