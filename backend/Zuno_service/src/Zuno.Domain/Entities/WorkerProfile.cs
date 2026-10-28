using Zuno.Domain.Common;
using Zuno.Domain.Enums;

namespace Zuno.Domain.Entities;

public class WorkerProfile : BaseEntity
{
    public Guid UserId { get; set; }

    public User User { get; set; } = null!;

    public short? ExperienceYears { get; set; }

    public decimal? HourlyRate { get; set; }

    public AvailabilityStatus AvailabilityStatus { get; set; } = AvailabilityStatus.Available;

    /// <summary>
    /// The worker's own picture, as a root-relative URL. Null until they upload one.
    /// </summary>
    /// <remarks>
    /// Written only by the command that uploads a file, never echoed back from a profile form — the
    /// same rule as a business logo, for the same reason: an edit form that posts the whole profile
    /// would otherwise wipe the picture as a side effect of a name change.
    /// </remarks>
    public string? PhotoUrl { get; set; }

    public VerificationStatus VerificationStatus { get; set; } = VerificationStatus.Pending;

    public decimal? CurrentLatitude { get; set; }

    public decimal? CurrentLongitude { get; set; }

    /// <summary>Where this worker gets paid. Null until they add their details.</summary>
    public WorkerPayoutDetail? PayoutDetail { get; set; }

    public ICollection<BusinessWorker> BusinessAssignments { get; set; } = new List<BusinessWorker>();

    public ICollection<BookingWorkerAssignment> BookingAssignments { get; set; } = new List<BookingWorkerAssignment>();
}
