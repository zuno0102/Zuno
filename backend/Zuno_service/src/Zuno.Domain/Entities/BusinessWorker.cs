using Zuno.Domain.Common;
using Zuno.Domain.Enums;

namespace Zuno.Domain.Entities;

public class BusinessWorker : BaseEntity
{
    public Guid BusinessOwnerProfileId { get; set; }

    public BusinessOwnerProfile BusinessOwnerProfile { get; set; } = null!;

    public Guid WorkerProfileId { get; set; }

    public WorkerProfile WorkerProfile { get; set; } = null!;

    public BusinessWorkerStatus AssignmentStatus { get; set; } = BusinessWorkerStatus.Invited;

    public DateTimeOffset InvitedAt { get; set; }

    public DateTimeOffset? RespondedAt { get; set; }

    // No job title here, deliberately. Being on a business's team says who may be put on its jobs
    // and nothing more; what somebody is on a particular job — the lead, the cook — belongs to
    // that job, and lives on BookingWorkerAssignment.Role. A title held business-wide said the
    // same person was the lead on every job at once, which is not how a crew is run.
}
