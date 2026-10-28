using MediatR;
using Zuno.Application.Modules.Booking.DTOs;

namespace Zuno.Application.Modules.Booking.Commands.SendBookingMessage;

/// <summary>
/// Writes a message on a booking, from whichever side is signed in.
/// </summary>
/// <remarks>
/// One command for both parties rather than a customer and a business version. Who is writing is a
/// fact about the signed-in user and the booking — never something the caller gets to assert — so
/// there is nothing for the two to differ on, and no way to send a message as the other side by
/// posting to the wrong endpoint.
/// </remarks>
public class SendBookingMessageCommand : IRequest<BookingMessageDto>
{
    public Guid BookingId { get; set; }

    public string Body { get; set; } = string.Empty;
}
