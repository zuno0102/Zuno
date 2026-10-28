using System.Text.Json.Serialization;
using MediatR;
using Zuno.Application.Modules.HiringPost.DTOs;

namespace Zuno.Application.Modules.HiringPost.Commands.RaisePostCrewSalary;

/// <summary>Adds the same extra amount to every unpaid worker on one of the business's own events.</summary>
public class RaisePostCrewSalaryCommand : IRequest<HiringPostDto>
{
    /// <summary>Bound from the route, not the body.</summary>
    [JsonIgnore]
    public Guid HiringPostId { get; set; }

    /// <summary>Added to each worker's wage: ₹1,000 with an increase of ₹200 becomes ₹1,200.</summary>
    public decimal Increase { get; set; }

    public string? Reason { get; set; }
}
