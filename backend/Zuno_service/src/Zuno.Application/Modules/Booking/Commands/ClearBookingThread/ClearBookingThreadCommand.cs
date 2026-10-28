using MediatR;

namespace Zuno.Application.Modules.Booking.Commands.ClearBookingThread;

/// <summary>
/// Clears a booking's conversation from the signed-in user's own list.
/// </summary>
/// <remarks>
/// Deliberately not a delete. The other side keeps everything: a thread is where a time or an
/// address was agreed, and one party must not be able to erase the other's record of it. This hides
/// what is there today from the person asking, and the thread returns if anybody writes again.
/// </remarks>
public class ClearBookingThreadCommand : IRequest<Unit>
{
    public Guid BookingId { get; set; }
}
