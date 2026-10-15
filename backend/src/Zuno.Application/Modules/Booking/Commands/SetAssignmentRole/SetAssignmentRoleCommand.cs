using MediatR;
using Zuno.Application.Modules.Booking.DTOs;

namespace Zuno.Application.Modules.Booking.Commands.SetAssignmentRole;

/// <summary>
/// Gives one of an order's crew a role on that job, or takes it away.
/// </summary>
/// <remarks>
/// <para>
/// Set from the order's crew list, on the person — long-press a name. The role belongs to this one
/// job: the same worker can lead Saturday's wedding and be an ordinary pair of hands on Sunday's,
/// which a title held across the whole business could never express.
/// </para>
/// <para>
/// A role is not decoration. Whoever holds one can say this job's work has started and that it has
/// finished — see <see cref="Zuno.Application.Modules.Booking.Common.BookingWorkControl"/> — which
/// is why only the owner may hand one out.
/// </para>
/// </remarks>
public class SetAssignmentRoleCommand : IRequest<BookingDto>
{
    public Guid BookingId { get; set; }

    /// <summary>Which of the crew. Not the assignment's own id, so the caller needs only the worker.</summary>
    public Guid WorkerProfileId { get; set; }

    /// <summary>
    /// What they are on this job — "Supervisor", "Lead", "Chef". Null or blank takes the role away.
    /// </summary>
    public string? Role { get; set; }
}
