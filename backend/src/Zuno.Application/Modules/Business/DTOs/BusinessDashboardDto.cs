namespace Zuno.Application.Modules.Business.DTOs;

/// <summary>
/// The business's home screen: what they have delivered, broken down by the kind of work, plus
/// the two-sided trust record.
/// </summary>
public class BusinessDashboardDto
{
    /// <summary>
    /// Customer bookings closed for good — event, crew, work and payment all done. The number
    /// that splits by category.
    /// </summary>
    public int EventsCompleted { get; set; }

    /// <summary>Confirmed bookings whose date is still ahead. Unconfirmed requests are not counted.</summary>
    public int UpcomingEvents { get; set; }

    /// <summary>Work marked complete while somebody on the crew is still unpaid.</summary>
    public int AwaitingPaymentEvents { get; set; }

    /// <summary>Bookings the business or customer called off.</summary>
    public int CancelledEvents { get; set; }

    /// <summary>Money from finished bookings.</summary>
    public decimal TotalRevenue { get; set; }

    /// <summary>
    /// Crew events run through hiring posts. Counted separately because a hiring post has no
    /// service category — it is a call for workers, not a booking of a service.
    /// </summary>
    public int CrewEventsCompleted { get; set; }

    /// <summary>
    /// Workers on the roster who have accepted and not been removed — the people the business
    /// can actually put on a job today.
    /// </summary>
    public int ActiveWorkers { get; set; }

    /// <summary>Services customers can find and book right now.</summary>
    public int ActiveServices { get; set; }

    /// <summary>Services the business has switched off: kept, but hidden from customers.</summary>
    public int InactiveServices { get; set; }

    /// <summary>Completed work grouped by main category, then by sub-category inside it.</summary>
    public List<CategoryBreakdownDto> ByCategory { get; set; } = [];

    /// <summary>Work done but a wage still owed, most recently finished first.</summary>
    public List<DashboardEventDto> AwaitingPayment { get; set; } = [];

    /// <summary>Bookings still to happen, soonest first.</summary>
    public List<DashboardEventDto> Upcoming { get; set; } = [];

    /// <summary>Bookings that were called off, most recent first.</summary>
    public List<DashboardEventDto> Cancelled { get; set; } = [];

    /// <summary>Crew events run through hiring posts, most recent first.</summary>
    public List<CrewEventDto> CrewEvents { get; set; } = [];

    /// <summary>The active roster, busiest people last so whoever is free reads first.</summary>
    public List<DashboardWorkerDto> Workers { get; set; } = [];

    /// <summary>Month-by-month customer activity, oldest first, for the trend chart.</summary>
    public List<MonthlyActivityDto> Trend { get; set; } = [];

    public BusinessTrustDto Trust { get; set; } = new();
}

/// <summary>One main category — "Painting 2" — and the sub-categories that make it up.</summary>
public class CategoryBreakdownDto
{
    public Guid ServiceCategoryId { get; set; }

    public string CategoryName { get; set; } = string.Empty;

    public int Count { get; set; }

    public decimal Revenue { get; set; }

    public List<SubCategoryBreakdownDto> SubCategories { get; set; } = [];
}

/// <summary>"Acrylic painting 1" — one line inside a category.</summary>
public class SubCategoryBreakdownDto
{
    public string Name { get; set; } = string.Empty;

    public int Count { get; set; }

    public decimal Revenue { get; set; }
}

/// <summary>One person on the roster, as the dashboard needs them.</summary>
/// <remarks>
/// Deliberately not <see cref="BusinessWorkerDto"/>: this list answers "who can I put on a job,
/// and how much have they done for me", which is a different question from managing the roster.
/// </remarks>
public class DashboardWorkerDto
{
    public Guid WorkerProfileId { get; set; }

    public string WorkerName { get; set; } = string.Empty;

    public string? WorkerPhone { get; set; }

    /// <summary>AtWork, Booked or Active — the same three the workers tab shows.</summary>
    public string AvailabilityStatus { get; set; } = string.Empty;

    /// <summary>Jobs they have finished for this business. What earns them the next one.</summary>
    public int JobsCompleted { get; set; }

    /// <summary>When they joined the roster.</summary>
    public DateTimeOffset SinceDate { get; set; }

    /// <summary>
    /// When the job holding them starts — the soonest one, if they are on more than one. Null
    /// for anyone free.
    /// </summary>
    /// <remarks>
    /// Carried because "Booked" on its own cannot be acted on: someone booked next month is
    /// available tomorrow, and the business has no way to tell the two apart without a date.
    /// </remarks>
    public DateTimeOffset? BusyOn { get; set; }

}

/// <summary>One month of customer activity.</summary>
public class MonthlyActivityDto
{
    /// <summary>"Sep", for the axis label.</summary>
    public string Label { get; set; } = string.Empty;

    public int Year { get; set; }

    public int Month { get; set; }

    public int Completed { get; set; }

    public decimal Revenue { get; set; }
}
