using Asp.Versioning;
using MediatR;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Zuno.Api.Authorization;
using Zuno.Application.Modules.Booking.Commands.CancelBooking;
using Zuno.Application.Modules.Booking.Commands.AcceptBookingTerms;
using Zuno.Application.Modules.Booking.Commands.CreateBooking;
using Zuno.Application.Modules.Booking.Commands.ProposeBookingTerms;
using Zuno.Application.Modules.Booking.Commands.RateBooking;
using Zuno.Application.Modules.Booking.Queries.GetBookingById;
using Zuno.Application.Modules.Booking.Queries.GetMyBookingsAsCustomer;

namespace Zuno.Api.Controllers;

[ApiController]
[ApiVersion("1.0")]
[Route("api/v{version:apiVersion}/customer/bookings")]
[Authorize(Policy = AuthorizationPolicyNames.RequireCustomerRole)]
public class CustomerBookingsController(ISender mediator) : ControllerBase
{
    [HttpGet]
    public async Task<IActionResult> GetMyBookings(CancellationToken cancellationToken)
    {
        var result = await mediator.Send(new GetMyBookingsAsCustomerQuery(), cancellationToken);
        return Ok(result);
    }

    [HttpGet("{id:guid}")]
    public async Task<IActionResult> GetById(Guid id, CancellationToken cancellationToken)
    {
        var result = await mediator.Send(new GetBookingByIdQuery { BookingId = id }, cancellationToken);
        return Ok(result);
    }

    [HttpPost]
    public async Task<IActionResult> Create(CreateBookingCommand command, CancellationToken cancellationToken)
    {
        var result = await mediator.Send(command, cancellationToken);
        return Ok(result);
    }

    [HttpPost("{id:guid}/cancel")]
    public async Task<IActionResult> Cancel(Guid id, [FromBody] CancelBookingRequest request, CancellationToken cancellationToken)
    {
        var result = await mediator.Send(new CancelBookingCommand { BookingId = id, Reason = request.Reason }, cancellationToken);
        return Ok(result);
    }

    /// <summary>Counters the business's offer with the customer's own number.</summary>
    /// <remarks>
    /// The same command the business uses. The handler works out which side is calling and
    /// enforces that only the other side may replace an open offer.
    /// </remarks>
    [HttpPost("{id:guid}/terms")]
    public async Task<IActionResult> ProposeTerms(
        Guid id,
        ProposeBookingTermsCommand command,
        CancellationToken cancellationToken)
    {
        command.BookingId = id;

        var result = await mediator.Send(command, cancellationToken);
        return Ok(result);
    }

    /// <summary>Takes up the business's offer, confirming the order.</summary>
    [HttpPost("{id:guid}/terms/{proposalId:guid}/accept")]
    public async Task<IActionResult> AcceptTerms(
        Guid id,
        Guid proposalId,
        CancellationToken cancellationToken)
    {
        var result = await mediator.Send(
            new AcceptBookingTermsCommand { BookingId = id, ProposalId = proposalId },
            cancellationToken);
        return Ok(result);
    }

    [HttpPost("{id:guid}/rate")]
    public async Task<IActionResult> Rate(Guid id, [FromBody] RateBookingRequest request, CancellationToken cancellationToken)
    {
        var result = await mediator.Send(
            new RateBookingCommand { BookingId = id, Score = request.Score, Comment = request.Comment },
            cancellationToken);
        return Ok(result);
    }
}

public class CancelBookingRequest
{
    public string? Reason { get; set; }
}

public class RateBookingRequest
{
    public short Score { get; set; }

    public string? Comment { get; set; }
}
