using MediatR;
using Zuno.Application.Modules.Booking.DTOs;

namespace Zuno.Application.Modules.Booking.Queries.GetMyBookingThreads;

/// <summary>
/// The signed-in user's conversations, newest activity first — what the Chat tab lists.
/// </summary>
/// <remarks>
/// Answers for whichever side is asking: a customer gets their own orders, a business gets the ones
/// placed with it. There is no separate customer and business version because the only difference is
/// which column the signed-in user matches on, and two near-identical handlers would be two places
/// for the unread rule to drift.
/// </remarks>
public record GetMyBookingThreadsQuery : IRequest<List<BookingThreadDto>>;
