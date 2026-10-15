using MediatR;
using Zuno.Application.Modules.Booking.DTOs;

namespace Zuno.Application.Modules.Booking.Commands.CompleteBookingWork;

/// <summary>The business marking the work on an order as finished.</summary>
/// <remarks>
/// Distinct from CompleteBookingCommand, which is the <em>worker</em> ticking off their own part.
/// The business owns the order and needs to be able to close it whether or not every crew member
/// remembered to.
/// </remarks>
public class CompleteBookingWorkCommand : IRequest<BookingDto>
{
    public Guid BookingId { get; set; }
}
