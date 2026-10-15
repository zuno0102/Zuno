using MediatR;
using Zuno.Application.Modules.Booking.DTOs;

namespace Zuno.Application.Modules.Booking.Queries.GetBookingMessages;

/// <summary>
/// One booking's conversation, oldest first, and marks the other side's messages read.
/// </summary>
/// <remarks>
/// Reading is what marks them read, which is why this writes despite being a query. The alternative
/// — a separate "mark as read" call from the client — can be forgotten, retried, or sent without
/// anybody having looked, and then the unread count on the chat list disagrees with what the person
/// has actually seen.
/// </remarks>
public record GetBookingMessagesQuery(Guid BookingId) : IRequest<List<BookingMessageDto>>;
