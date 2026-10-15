using System.Text.Json.Serialization;
using MediatR;
using Zuno.Application.Modules.HiringPost.DTOs;

namespace Zuno.Application.Modules.HiringPost.Commands.RaiseAgreedSalary;

public class RaiseAgreedSalaryCommand : IRequest<HiringPostDto>
{
    /// <summary>Bound from the route, not the body.</summary>
    [JsonIgnore]
    public Guid ApplicationId { get; set; }

    public decimal NewAmount { get; set; }

    public string? Reason { get; set; }
}
