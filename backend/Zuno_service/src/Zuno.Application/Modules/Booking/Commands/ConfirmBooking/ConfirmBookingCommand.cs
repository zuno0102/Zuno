using MediatR;
using Zuno.Application.Modules.Booking.DTOs;

namespace Zuno.Application.Modules.Booking.Commands.ConfirmBooking;

public class ConfirmBookingCommand : IRequest<BookingDto>
{
    public Guid BookingId { get; set; }
}
