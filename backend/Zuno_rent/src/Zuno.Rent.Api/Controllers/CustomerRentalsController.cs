using MediatR;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Zuno.Rent.Api.Common;
using Zuno.Rent.Application.Customer;
using Zuno.Rent.Application.Orders;

namespace Zuno.Rent.Api.Controllers;

/// <summary>Browsing rent items: the home, search, featured items, an item, and what is free for some dates.</summary>
[ApiController]
[Route("api/v1/rentals")]
[Authorize(Policy = RentPolicies.Customer)]
public class CustomerRentalsController(ISender mediator) : ControllerBase
{
    [HttpGet("home")]
    public async Task<IActionResult> Home([FromQuery] int seed, [FromQuery] List<Guid>? districtIds, CancellationToken cancellationToken) =>
        Ok(await mediator.Send(new GetRentalHomeQuery { Seed = seed, DistrictIds = districtIds ?? [] }, cancellationToken));

    [HttpGet]
    public async Task<IActionResult> Search(
        [FromQuery] Guid? categoryId,
        [FromQuery] string? keyword,
        [FromQuery] List<Guid>? districtIds,
        CancellationToken cancellationToken) =>
        Ok(await mediator.Send(
            new SearchRentalsQuery { CategoryId = categoryId, Keyword = keyword, DistrictIds = districtIds ?? [] },
            cancellationToken));

    [HttpGet("banners")]
    public async Task<IActionResult> Banners([FromQuery] List<Guid>? districtIds, CancellationToken cancellationToken) =>
        Ok(await mediator.Send(new GetRentalBannersQuery { DistrictIds = districtIds ?? [] }, cancellationToken));

    [HttpGet("{id:guid}")]
    public async Task<IActionResult> Get(Guid id, CancellationToken cancellationToken) =>
        Ok(await mediator.Send(new GetRentalItemDetailQuery { Id = id }, cancellationToken));

    [HttpGet("{id:guid}/availability")]
    public async Task<IActionResult> Availability(
        Guid id, [FromQuery] DateTimeOffset start, [FromQuery] DateTimeOffset end, CancellationToken cancellationToken) =>
        Ok(await mediator.Send(
            new GetCustomerRentalAvailabilityQuery { RentalItemId = id, StartDate = start, EndDate = end },
            cancellationToken));
}

/// <summary>The customer's rent orders: book, list, open, cancel, the history, and messages with the business.</summary>
[ApiController]
[Route("api/v1/customer/rental-orders")]
[Authorize(Policy = RentPolicies.Customer)]
public class CustomerRentalOrdersController(ISender mediator) : ControllerBase
{
    [HttpPost]
    public async Task<IActionResult> Book([FromBody] BookRentalCommand command, CancellationToken cancellationToken) =>
        StatusCode(StatusCodes.Status201Created, await mediator.Send(command, cancellationToken));

    [HttpGet]
    public async Task<IActionResult> Mine([FromQuery] int page = 1, [FromQuery] int? pageSize = null, CancellationToken cancellationToken = default) =>
        Ok(await mediator.Send(new GetMyRentalsQuery { Page = page, PageSize = pageSize }, cancellationToken));

    [HttpGet("threads")]
    public async Task<IActionResult> Threads(CancellationToken cancellationToken) =>
        Ok(await mediator.Send(new GetMyRentalOrderThreadsQuery(), cancellationToken));

    [HttpGet("{id:guid}")]
    public async Task<IActionResult> Get(Guid id, CancellationToken cancellationToken) =>
        Ok(await mediator.Send(new GetMyRentalQuery { Id = id }, cancellationToken));

    /// <summary>What cancelling now would cost and give back, by the steps the order was booked with.</summary>
    [HttpGet("{id:guid}/cancel-quote")]
    public async Task<IActionResult> CancelQuote(Guid id, CancellationToken cancellationToken) =>
        Ok(await mediator.Send(new GetMyRentalCancelQuoteQuery { Id = id }, cancellationToken));

    [HttpPost("{id:guid}/cancel")]
    public async Task<IActionResult> Cancel(Guid id, CancellationToken cancellationToken) =>
        Ok(await mediator.Send(new CancelMyRentalCommand { Id = id }, cancellationToken));

    [HttpGet("{id:guid}/history")]
    public async Task<IActionResult> History(Guid id, CancellationToken cancellationToken) =>
        Ok(await mediator.Send(new GetMyRentalOrderHistoryQuery { RentalOrderId = id }, cancellationToken));

    [HttpGet("{id:guid}/messages")]
    public async Task<IActionResult> Messages(Guid id, CancellationToken cancellationToken) =>
        Ok(await mediator.Send(new GetMyRentalOrderMessagesQuery { RentalOrderId = id }, cancellationToken));

    [HttpPost("{id:guid}/messages")]
    public async Task<IActionResult> Send(Guid id, [FromBody] SendMyRentalOrderMessageCommand command, CancellationToken cancellationToken)
    {
        command.RentalOrderId = id;
        return StatusCode(StatusCodes.Status201Created, await mediator.Send(command, cancellationToken));
    }

    /// <summary>Starts an online payment: the advance while it is awaited, otherwise what is due.</summary>
    [HttpPost("{id:guid}/checkout")]
    public async Task<IActionResult> Checkout(Guid id, CancellationToken cancellationToken) =>
        Ok(await mediator.Send(new StartRentalPaymentCommand { Id = id }, cancellationToken));

    /// <summary>The gateway's answer for that payment; counted once its signature checks out.</summary>
    [HttpPost("{id:guid}/pay")]
    public async Task<IActionResult> Pay(Guid id, [FromBody] CompleteRentalPaymentCommand command, CancellationToken cancellationToken)
    {
        command.Id = id;
        return Ok(await mediator.Send(command, cancellationToken));
    }
}
