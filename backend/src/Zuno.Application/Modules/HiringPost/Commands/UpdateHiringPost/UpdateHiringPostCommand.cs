using System.Text.Json.Serialization;
using MediatR;
using Zuno.Application.Modules.HiringPost.DTOs;
using Zuno.Domain.Enums;

namespace Zuno.Application.Modules.HiringPost.Commands.UpdateHiringPost;

public class UpdateHiringPostCommand : IRequest<HiringPostDto>
{
    /// <summary>Bound from the route, not the body.</summary>
    [JsonIgnore]
    public Guid HiringPostId { get; set; }

    public string Title { get; set; } = string.Empty;

    public string? Description { get; set; }

    public DateTimeOffset EventDate { get; set; }

    /// <summary>How long the work runs, in minutes. Used to detect clashes in a worker.s day.</summary>
    public int DurationMinutes { get; set; } = 120;

    public string? Location { get; set; }

    /// <summary>
    /// The job's exact point, picked on a map or from the device's location. Both or neither.
    /// Ignored on a post raised from an order that has its own pinned address — the order wins.
    /// </summary>
    public decimal? Latitude { get; set; }

    public decimal? Longitude { get; set; }

    /// <summary>"Pinned" (picked on a map or GPS) or "Geocoded" (a searched place). Defaults to pinned.</summary>
    public string? LocationPrecision { get; set; }

    /// <summary>The kind of work inside the category — what a worker actually judges the job by.</summary>
    public Guid? ServiceSubCategoryId { get; set; }


    public int WorkersNeeded { get; set; } = 1;

    public decimal SalaryAmount { get; set; }

    public SalaryUnit SalaryUnit { get; set; } = SalaryUnit.PerEvent;
}
