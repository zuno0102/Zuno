using MediatR;
using Zuno.Application.Modules.HiringPost.DTOs;
using Zuno.Domain.Enums;

namespace Zuno.Application.Modules.HiringPost.Commands.CreateHiringPost;

public class CreateHiringPostCommand : IRequest<HiringPostDto>
{
    /// <summary>
    /// The customer booking this crew is for. Optional — omit it for a standalone post.
    /// When set, every worker who accepts is assigned to that booking automatically.
    /// </summary>
    public Guid? BookingId { get; set; }

    public string Title { get; set; } = string.Empty;

    public string? Description { get; set; }

    public DateTimeOffset EventDate { get; set; }

    /// <summary>How long the work runs, in minutes. Used to detect clashes in a worker.s day.</summary>
    public int DurationMinutes { get; set; } = 120;

    public string? Location { get; set; }

    /// <summary>The kind of work inside the category — what a worker actually judges the job by.</summary>
    public Guid? ServiceSubCategoryId { get; set; }


    public int WorkersNeeded { get; set; } = 1;

    public decimal SalaryAmount { get; set; }

    public SalaryUnit SalaryUnit { get; set; } = SalaryUnit.PerEvent;
}
