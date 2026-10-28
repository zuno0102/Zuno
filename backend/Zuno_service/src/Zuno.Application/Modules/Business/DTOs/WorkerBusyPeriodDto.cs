namespace Zuno.Application.Modules.Business.DTOs;

/// <summary>One block of time a worker is spoken for.</summary>
/// <remarks>
/// Times and nothing else. A worker's diary spans every business they serve, so naming the work
/// would show one business another's customers — and the question this answers is only "when is
/// this person unavailable", which a name does not help with.
/// </remarks>
public class WorkerBusyPeriodDto
{
    public DateTimeOffset StartsAt { get; set; }

    /// <summary>
    /// When it ends. Computed rather than stored — a booking carries no duration column, so this
    /// rests on the package's estimate, then the service's, then a two-hour default.
    /// </summary>
    public DateTimeOffset EndsAt { get; set; }
}
