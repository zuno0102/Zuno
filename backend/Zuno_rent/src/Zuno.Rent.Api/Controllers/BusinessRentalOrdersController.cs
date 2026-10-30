using MediatR;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Zuno.Rent.Api.Common;
using Zuno.Rent.Application.Orders;

namespace Zuno.Rent.Api.Controllers;

/// <summary>A business's rent orders: the list, each order's next step, and messages with the customer.</summary>
[ApiController]
[Route("api/v1/business/rental-orders")]
[Authorize(Policy = RentPolicies.BusinessOwner)]
public class BusinessRentalOrdersController(ISender mediator) : ControllerBase
{
    [HttpGet]
    public async Task<IActionResult> GetMine(
        [FromQuery] string? status = null,
        [FromQuery] int page = 1,
        [FromQuery] int? pageSize = null,
        CancellationToken cancellationToken = default) =>
        Ok(await mediator.Send(new GetMyRentalOrdersQuery { Status = status, Page = page, PageSize = pageSize }, cancellationToken));

    /// <summary>How many orders sit in each status — the filter chips.</summary>
    [HttpGet("counts")]
    public async Task<IActionResult> GetCounts(CancellationToken cancellationToken) =>
        Ok(await mediator.Send(new GetRentalOrderCountsQuery(), cancellationToken));

    /// <summary>Conversations with customers about rent orders, latest first.</summary>
    [HttpGet("threads")]
    public async Task<IActionResult> GetThreads(CancellationToken cancellationToken) =>
        Ok(await mediator.Send(new GetRentalOrderThreadsQuery(), cancellationToken));

    /// <summary>Books pieces for a customer who phoned or came in; refused when the dates do not leave enough.</summary>
    [HttpPost]
    public async Task<IActionResult> Create([FromBody] CreateRentalOrderCommand command, CancellationToken cancellationToken) =>
        StatusCode(StatusCodes.Status201Created, await mediator.Send(command, cancellationToken));

    /// <summary>More pieces for a running order — a new order linked to it.</summary>
    [HttpPost("{id:guid}/add-on")]
    public async Task<IActionResult> AddOn(Guid id, [FromBody] AddRentalOrderAddOnCommand command, CancellationToken cancellationToken)
    {
        command.ParentOrderId = id;
        return StatusCode(StatusCodes.Status201Created, await mediator.Send(command, cancellationToken));
    }

    [HttpGet("{id:guid}")]
    public async Task<IActionResult> Get(Guid id, CancellationToken cancellationToken) =>
        Ok(await mediator.Send(new GetRentalOrderQuery { Id = id }, cancellationToken));

    /// <summary>Money taken for the order — cash or UPI QR — or given back on a cancelled one.</summary>
    [HttpPost("{id:guid}/payments")]
    public async Task<IActionResult> RecordPayment(Guid id, [FromBody] RecordRentalPaymentCommand command, CancellationToken cancellationToken)
    {
        command.Id = id;
        return Ok(await mediator.Send(command, cancellationToken));
    }

    /// <summary>Moves the order one step, e.g. Booked → On rent ("Send out").</summary>
    [HttpPost("{id:guid}/status")]
    public async Task<IActionResult> ChangeStatus(Guid id, [FromBody] ChangeRentalOrderStatusCommand command, CancellationToken cancellationToken)
    {
        // The route decides which order; an id in the body is ignored.
        command.Id = id;
        return Ok(await mediator.Send(command, cancellationToken));
    }

    /// <summary>Every step of the order and its add-ons, oldest first — the record, never edited.</summary>
    [HttpGet("{id:guid}/history")]
    public async Task<IActionResult> GetHistory(Guid id, CancellationToken cancellationToken) =>
        Ok(await mediator.Send(new GetRentalOrderHistoryQuery { RentalOrderId = id }, cancellationToken));

    [HttpGet("{id:guid}/messages")]
    public async Task<IActionResult> GetMessages(Guid id, CancellationToken cancellationToken) =>
        Ok(await mediator.Send(new GetRentalOrderMessagesQuery { RentalOrderId = id }, cancellationToken));

    [HttpPost("{id:guid}/messages")]
    public async Task<IActionResult> SendMessage(Guid id, [FromBody] SendRentalOrderMessageCommand command, CancellationToken cancellationToken)
    {
        command.RentalOrderId = id;
        return StatusCode(StatusCodes.Status201Created, await mediator.Send(command, cancellationToken));
    }
}
