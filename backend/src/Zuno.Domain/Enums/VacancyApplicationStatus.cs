namespace Zuno.Domain.Enums;

/// <summary>
/// Where an application stands. The worker reads it as "Application sent", "Application viewed" and so
/// on; the business works through it as New → Waiting → Shortlisted → Hired. Hiring itself happens
/// outside the app.
/// </summary>
public enum VacancyApplicationStatus : short
{
    /// <summary>Sent, and the business has not opened it yet — its New list.</summary>
    Applied = 1,

    Shortlisted = 2,

    Hired = 3,

    /// <summary>Turned down. Leaves every business list, and what the worker sent is deleted.</summary>
    Rejected = 4,

    /// <summary>The business opened it but has not decided — its Waiting list. Set by opening, never chosen.</summary>
    Viewed = 5,
}
