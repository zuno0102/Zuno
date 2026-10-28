using MediatR;
using Zuno.Application.Modules.Booking.DTOs;

namespace Zuno.Application.Modules.Booking.Commands.StartBookingWork;

/// <summary>The business marking a confirmed order as actually under way.</summary>
public class StartBookingWorkCommand : IRequest<BookingDto>
{
    public Guid BookingId { get; set; }
}
