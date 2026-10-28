using MediatR;
using Zuno.Application.Modules.Booking.DTOs;

namespace Zuno.Application.Modules.Booking.Commands.RateBooking;

public class RateBookingCommand : IRequest<RatingDto>
{
    public Guid BookingId { get; set; }

    public short Score { get; set; }

    public string? Comment { get; set; }
}
