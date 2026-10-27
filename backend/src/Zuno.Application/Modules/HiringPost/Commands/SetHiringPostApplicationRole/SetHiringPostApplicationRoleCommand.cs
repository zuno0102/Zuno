using System.Text.Json.Serialization;
using MediatR;
using Zuno.Application.Modules.HiringPost.DTOs;

namespace Zuno.Application.Modules.HiringPost.Commands.SetHiringPostApplicationRole;

/// <summary>
/// Gives one of an own event's crew a role on that job, or takes it away — the own-event twin of
/// <c>SetAssignmentRoleCommand</c> on an order.
/// </summary>
/// <remarks>
/// Whoever holds Lead can start and finish this job's work (see
/// <see cref="Common.HiringPostWorkControl"/>), which is why only the owner may hand one out.
/// </remarks>
public class SetHiringPostApplicationRoleCommand : IRequest<HiringPostDto>
{
    /// <summary>Bound from the route, not the body.</summary>
    [JsonIgnore]
    public Guid ApplicationId { get; set; }

    /// <summary>Supervisor, Lead or Support. Null or blank takes the role away.</summary>
    public string? Role { get; set; }
}
