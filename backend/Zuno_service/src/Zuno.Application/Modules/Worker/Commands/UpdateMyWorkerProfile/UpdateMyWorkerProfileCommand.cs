using MediatR;
using Zuno.Application.Modules.Worker.DTOs;

namespace Zuno.Application.Modules.Worker.Commands.UpdateMyWorkerProfile;

/// <summary>
/// What a worker may change about themselves.
/// </summary>
/// <remarks>
/// <para>
/// Until now a worker could change nothing: their details were written once at registration and
/// there was no update path anywhere in the backend. The two consequences were real — a worker who
/// signed up with an email only could never be phoned, and one with no UPI could never be paid,
/// with no way for either of them to fix it.
/// </para>
/// <para>
/// Every field is nullable and null means "leave it alone", because the form does not necessarily
/// carry the whole profile. Clearing a value is therefore not expressible, which is deliberate: an
/// accidentally blank field must not wipe the only way someone has of being paid.
/// </para>
/// </remarks>
public class UpdateMyWorkerProfileCommand : IRequest<WorkerProfileDto>
{
    /// <summary>
    /// The worker's own name, as businesses see it on every job card and crew list.
    /// </summary>
    /// <remarks>
    /// Editable because it was the one detail with no way back: a name typed wrong at registration —
    /// or a name that changes — followed the worker onto every job they ever applied for, and the
    /// only route to a correction was asking someone with database access.
    /// </remarks>
    public string? FirstName { get; set; }

    /// <inheritdoc cref="FirstName"/>
    public string? LastName { get; set; }

    /// <summary>A 10-digit Indian mobile number. Must not already belong to another account.</summary>
    public string? PhoneNumber { get; set; }

    /// <summary>
    /// A UPI address such as "ravi@okhdfcbank". Changing it sends the destination back for
    /// verification, since the new address has not been checked.
    /// </summary>
    public string? UpiVpa { get; set; }

    public decimal? HourlyRate { get; set; }

    public short? ExperienceYears { get; set; }
}
