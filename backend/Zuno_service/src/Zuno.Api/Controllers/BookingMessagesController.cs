using Asp.Versioning;
using MediatR;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Zuno.Application.Modules.Booking.Commands.ClearBookingThread;
using Zuno.Application.Modules.Booking.Commands.SendBookingMessage;
using Zuno.Application.Modules.Booking.Queries.GetBookingMessages;
using Zuno.Application.Modules.Booking.Queries.GetMyBookingThreads;

namespace Zuno.Api.Controllers;

/// <summary>
/// Messages between the customer and the business on a booking.
/// </summary>
/// <remarks>
/// One controller for both sides rather than a customer and a business copy. Who is asking is
/// established from the booking itself in every handler, so a role-split here would add two routes
/// and no safety — and would invite a future endpoint that trusts the route instead of the booking.
///
/// Authorised for any signed-in user for the same reason: the policy that matters is "are you party
/// to this booking", which a role claim cannot answer.
/// </remarks>
[ApiController]
[ApiVersion("1.0")]
[Route("api/v{version:apiVersion}/bookings")]
[Authorize]
public class BookingMessagesController(ISender mediator) : ControllerBase
{
    /// <summary>Every booking the signed-in user has a conversation on.</summary>
    [HttpGet("threads")]
    public async Task<IActionResult> GetThreads(CancellationToken cancellationToken)
    {
        var result = await mediator.Send(new GetMyBookingThreadsQuery(), cancellationToken);
        return Ok(result);
    }

    /// <summary>One booking's thread, oldest first. Reading it marks the other side's messages read.</summary>
    [HttpGet("{bookingId:guid}/messages")]
    public async Task<IActionResult> GetMessages(
        Guid bookingId,
        CancellationToken cancellationToken)
    {
        var result = await mediator.Send(
            new GetBookingMessagesQuery(bookingId),
            cancellationToken);
        return Ok(result);
    }

    /// <summary>Clears the thread from the caller's own list. The other side keeps theirs.</summary>
    [HttpDelete("{bookingId:guid}/messages")]
    public async Task<IActionResult> Clear(Guid bookingId, CancellationToken cancellationToken)
    {
        await mediator.Send(new ClearBookingThreadCommand { BookingId = bookingId }, cancellationToken);
        return NoContent();
    }

    [HttpPost("{bookingId:guid}/messages")]
    public async Task<IActionResult> Send(
        Guid bookingId,
        [FromBody] SendBookingMessageRequest request,
        CancellationToken cancellationToken)
    {
        var result = await mediator.Send(
            new SendBookingMessageCommand { BookingId = bookingId, Body = request.Body },
            cancellationToken);
        return Ok(result);
    }
}

/// <summary>The body of a message. The booking comes from the route, and the sender from the token.</summary>
public class SendBookingMessageRequest
{
    public string Body { get; set; } = string.Empty;
}
