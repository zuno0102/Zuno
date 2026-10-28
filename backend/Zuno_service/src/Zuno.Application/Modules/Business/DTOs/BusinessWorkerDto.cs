namespace Zuno.Application.Modules.Business.DTOs;

public class BusinessWorkerDto
{
    public Guid Id { get; set; }

    public Guid WorkerProfileId { get; set; }

    public string WorkerName { get; set; } = string.Empty;

    public string? WorkerEmail { get; set; }

    public string? WorkerPhone { get; set; }

    public string Status { get; set; } = string.Empty;

    /// <summary>
    /// AtWork, Booked or Active. Whether the worker is spoken for — never when. One date could
    /// only show the first of however many jobs they hold; the schedule endpoint reports them
    /// all, and that is what the card opens.
    /// </summary>
    public string AvailabilityStatus { get; set; } = string.Empty;

    public DateTimeOffset InvitedAt { get; set; }

    public DateTimeOffset? RespondedAt { get; set; }
}
