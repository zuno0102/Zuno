using MediatR;
using Zuno.Application.Modules.Booking.DTOs;

namespace Zuno.Application.Modules.Booking.Commands.AssignWorker;

public class AssignWorkerCommand : IRequest<BookingDto>
{
    public Guid BookingId { get; set; }

    public Guid WorkerProfileId { get; set; }

    public DateTimeOffset? ScheduledDate { get; set; }

    /// <summary>What this worker is paid for this job. Optional.</summary>
    /// <remarks>
    /// Left out for someone the business settles with outside Zuno — a regular on a monthly wage.
    /// Given, it puts them in the order's wage rollup and in its pay run, exactly like a worker
    /// hired through a post.
    /// </remarks>
    public decimal? SalaryAmount { get; set; }

    /// <summary>PerEvent, PerDay or PerHour. Required whenever an amount is given.</summary>
    public string? SalaryUnit { get; set; }
}
