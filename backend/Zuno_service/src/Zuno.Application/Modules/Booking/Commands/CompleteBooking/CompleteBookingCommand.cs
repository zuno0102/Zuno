using MediatR;
using Zuno.Application.Modules.Booking.DTOs;

namespace Zuno.Application.Modules.Booking.Commands.CompleteBooking;

public class CompleteBookingCommand : IRequest<BookingDto>
{
    public Guid BookingId { get; set; }
}
