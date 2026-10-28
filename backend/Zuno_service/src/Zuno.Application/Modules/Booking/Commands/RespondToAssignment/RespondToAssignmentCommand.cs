using MediatR;
using Zuno.Application.Modules.Booking.DTOs;

namespace Zuno.Application.Modules.Booking.Commands.RespondToAssignment;

public class RespondToAssignmentCommand : IRequest<BookingDto>
{
    public Guid BookingId { get; set; }

    public bool Accept { get; set; }
}
