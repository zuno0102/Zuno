using MediatR;
using Zuno.Application.Modules.Booking.DTOs;

namespace Zuno.Application.Modules.Booking.Commands.RaiseCrewMemberSalary;

/// <summary>
/// Adds extra pay to one worker the business put on this order directly — ₹1,000 plus ₹200 for
/// three extra hours. Workers hired through the order's hiring post are raised on the post instead.
/// </summary>
public class RaiseCrewMemberSalaryCommand : IRequest<BookingDto>
{
    public Guid BookingId { get; set; }

    /// <summary>Which of the crew, as the owner sees them on the crew list.</summary>
    public Guid WorkerProfileId { get; set; }

    /// <summary>Added to the worker's wage, never a replacement for it.</summary>
    public decimal Increase { get; set; }

    public string? Reason { get; set; }
}
