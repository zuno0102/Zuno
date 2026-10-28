using MediatR;
using Zuno.Application.Modules.Booking.DTOs;

namespace Zuno.Application.Modules.Booking.Commands.UpdateCrewSize;

public class UpdateCrewSizeCommand : IRequest<BookingDto>
{
    public Guid BookingId { get; set; }

    public int RequiredWorkerCount { get; set; }
}
