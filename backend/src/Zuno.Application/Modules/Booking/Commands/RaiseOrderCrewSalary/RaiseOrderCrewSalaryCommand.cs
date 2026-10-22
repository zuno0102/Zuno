using MediatR;
using Zuno.Application.Modules.Booking.DTOs;

namespace Zuno.Application.Modules.Booking.Commands.RaiseOrderCrewSalary;

/// <summary>
/// "Raise all" on an order: the same extra amount on every crew member still to be paid, whether
/// the business added them directly or hired them through the order's hiring post.
/// </summary>
public class RaiseOrderCrewSalaryCommand : IRequest<BookingDto>
{
    public Guid BookingId { get; set; }

    /// <summary>Added to each worker's wage: five at ₹1,000 with ₹200 each become five at ₹1,200.</summary>
    public decimal Increase { get; set; }

    public string? Reason { get; set; }
}
