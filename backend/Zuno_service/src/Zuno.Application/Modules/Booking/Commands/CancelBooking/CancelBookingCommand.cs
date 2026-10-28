using MediatR;
using Zuno.Application.Modules.Booking.DTOs;

namespace Zuno.Application.Modules.Booking.Commands.CancelBooking;

public class CancelBookingCommand : IRequest<BookingDto>
{
    public Guid BookingId { get; set; }

    public string? Reason { get; set; }
}
