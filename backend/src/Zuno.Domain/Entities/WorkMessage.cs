using Zuno.Domain.Common;
using Zuno.Domain.Enums;

namespace Zuno.Domain.Entities;

/// <summary>
/// One message between a business and a worker on its team.
/// </summary>
/// <remarks>
/// Attached to the pair, not to a job — the opposite choice from <see cref="BookingMessage"/>, and
/// for the opposite reason. A customer's three bookings are three different conversations; a worker
/// and the business that hires them have one working relationship, and "can you also do Saturday?"
/// spans jobs. One thread per pair, like any messaging app, and nothing lost between jobs.
///
/// Open while the worker is on the business's team (an active <see cref="BusinessWorker"/>), which is
/// what accepting a job makes them. Customers never take part: the business is the middle man, and
/// workers and customers do not contact each other directly.
/// </remarks>
public class WorkMessage : BaseEntity
{
    public Guid BusinessOwnerProfileId { get; set; }

    public BusinessOwnerProfile BusinessOwnerProfile { get; set; } = null!;

    public Guid WorkerProfileId { get; set; }

    public WorkerProfile WorkerProfile { get; set; } = null!;

    /// <summary>Which side sent it. Stored, for the same reason as on a booking message.</summary>
    public WorkThreadRole SenderRole { get; set; }

    public Guid SenderUserId { get; set; }

    public string Body { get; set; } = string.Empty;

    /// <summary>When the other side read it, or null while it is still unread.</summary>
    public DateTimeOffset? ReadAt { get; set; }

    public bool IsUnread => ReadAt is null;
}
