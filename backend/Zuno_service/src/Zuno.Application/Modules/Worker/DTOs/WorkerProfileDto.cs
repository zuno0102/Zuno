namespace Zuno.Application.Modules.Worker.DTOs;

/// <summary>
/// A worker's own profile: what they have earned, what they are owed, and whether they are
/// actually set up to receive it.
/// </summary>
/// <remarks>
/// Payout details lead, because a worker with no verified destination cannot be paid at all —
/// the payout handler refuses. Burying that in settings is a direct cause of unpaid wages.
/// </remarks>
public class WorkerProfileDto
{
    public Guid Id { get; set; }

    public string FullName { get; set; } = string.Empty;

    public string? PhoneNumber { get; set; }

    public string Email { get; set; } = string.Empty;

    public short? ExperienceYears { get; set; }

    public decimal? HourlyRate { get; set; }

    public string AvailabilityStatus { get; set; } = string.Empty;

    public string VerificationStatus { get; set; } = string.Empty;

    /// <summary>The worker's own picture, or null if they have not added one.</summary>
    public string? PhotoUrl { get; set; }

    // ---- Standing -------------------------------------------------------------------------

    /// <summary>1–5, earned from finished work.</summary>
    public int Level { get; set; } = 1;

    /// <summary>What to call the level. Describes experience, never quality — there are no ratings yet.</summary>
    public string LevelName { get; set; } = string.Empty;

    /// <summary>How many more jobs until the next level, or null at the top.</summary>
    public int? JobsToNextLevel { get; set; }

    /// <summary>
    /// The nearest thing standing between this worker and the next level, in their own words —
    /// "3 more jobs", "work for 2 more businesses" — or null at the top.
    /// </summary>
    /// <remarks>
    /// Sent because the level no longer rests on jobs alone, so a job count on its own could say
    /// "0 jobs to level 3" to somebody held back by something else entirely.
    /// </remarks>
    public string? NextLevelRequirement { get; set; }

    // ---- Getting paid ---------------------------------------------------------------------

    /// <summary>Masked for display — the last segment only, never the whole handle in a list.</summary>
    public string? UpiVpa { get; set; }

    public bool HasPayoutDestination { get; set; }

    public bool CanReceivePayouts { get; set; }

    public string PayoutVerificationStatus { get; set; } = string.Empty;

    // ---- Work record ----------------------------------------------------------------------

    /// <summary>Wages actually received.</summary>
    public decimal TotalEarned { get; set; }

    /// <summary>Agreed wages on finished work that has not been paid.</summary>
    public decimal OwedToYou { get; set; }

    public int JobsCompleted { get; set; }

    public int JobsPaid { get; set; }

    public decimal? AverageSalary { get; set; }

    /// <summary>Distinct businesses this worker has been hired by.</summary>
    public int BusinessesWorkedFor { get; set; }

    public int OffersDeclined { get; set; }

    /// <summary>Times this worker reported wages never arrived and it is still unresolved.</summary>
    public int OpenDisputes { get; set; }
}
