using MediatR;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.RateLimiting;
using Microsoft.Extensions.Options;
using Zuno.Marketplace.Api.Common;
using Zuno.Marketplace.Application.Orders;
using Zuno.Marketplace.Infrastructure.Services;

namespace Zuno.Marketplace.Api.Controllers;

/// <summary>
/// A business's product orders and B2B requests: list, open, move on, ship with a courier, and how
/// customers may pay.
/// </summary>
[ApiController]
[Route("api/v1/business/marketplace")]
[Authorize(Policy = MarketplacePolicies.BusinessOwner)]
public class BusinessMarketplaceOrdersController(ISender mediator, IOptions<MarketplaceFileStorageSettings> fileStorage) : ControllerBase
{
    [HttpGet("orders")]
    public async Task<IActionResult> GetOrders(
        [FromQuery] string? status = null,
        [FromQuery] int page = 1,
        [FromQuery] int? pageSize = null,
        CancellationToken cancellationToken = default) =>
        Ok(await mediator.Send(new GetBusinessMarketplaceOrdersQuery { Status = status, Page = page, PageSize = pageSize }, cancellationToken));

    [HttpGet("orders/{id:guid}")]
    public async Task<IActionResult> GetOrder(Guid id, CancellationToken cancellationToken) =>
        Ok(await mediator.Send(new GetBusinessMarketplaceOrderQuery { Id = id }, cancellationToken));

    /// <summary>Confirm order, Out for delivery, Mark delivered.</summary>
    [HttpPatch("orders/{id:guid}/status")]
    public async Task<IActionResult> ChangeStatus(Guid id, [FromBody] ChangeMarketplaceOrderStatusCommand command, CancellationToken cancellationToken)
    {
        // The route decides which order; an id in the body is ignored.
        command.Id = id;
        return Ok(await mediator.Send(command, cancellationToken));
    }

    [HttpPost("orders/{id:guid}/ship")]
    public async Task<IActionResult> Ship(Guid id, [FromBody] ShipMarketplaceOrderCommand command, CancellationToken cancellationToken)
    {
        command.Id = id;
        return Ok(await mediator.Send(command, cancellationToken));
    }

    /// <summary>A photo of the courier's receipt.</summary>
    [HttpPost("orders/{id:guid}/receipt")]
    [RequestSizeLimit(10_000_000)]
    [EnableRateLimiting(MarketplacePolicies.UploadPolicy)]
    public async Task<IActionResult> UploadReceipt(Guid id, IFormFile? file, CancellationToken cancellationToken)
    {
        if (file is null || file.Length == 0)
        {
            return Fail("No file was uploaded.");
        }

        var max = fileStorage.Value.MaxFileSizeBytes;
        if (file.Length > max)
        {
            return Fail($"Image must be {max / (1024 * 1024)}MB or smaller.");
        }

        var extension = await MediaUpload.ImageExtensionAsync(file, cancellationToken);
        if (extension is null)
        {
            return Fail(MediaUpload.ImageRule);
        }

        // Handed to the command, which saves it only after checking the order is the caller's.
        await using var stream = file.OpenReadStream();
        return Ok(await mediator.Send(
            new SetMarketplaceOrderReceiptCommand { OrderId = id, Content = stream, FileExtension = extension },
            cancellationToken));
    }

    [HttpGet("payment-settings")]
    public async Task<IActionResult> GetPaymentSettings(CancellationToken cancellationToken) =>
        Ok(await mediator.Send(new GetMarketplacePaymentSettingsQuery(), cancellationToken));

    [HttpPut("payment-settings")]
    public async Task<IActionResult> UpdatePaymentSettings(
        [FromBody] UpdateMarketplacePaymentSettingsCommand command, CancellationToken cancellationToken) =>
        Ok(await mediator.Send(command, cancellationToken));

    [HttpGet("b2b-requests")]
    public async Task<IActionResult> GetB2BRequests(
        [FromQuery] string? status = null,
        [FromQuery] int page = 1,
        [FromQuery] int? pageSize = null,
        CancellationToken cancellationToken = default) =>
        Ok(await mediator.Send(new GetBusinessB2BRequestsQuery { Status = status, Page = page, PageSize = pageSize }, cancellationToken));

    [HttpPost("b2b-requests/{id:guid}/accept")]
    public async Task<IActionResult> Accept(Guid id, CancellationToken cancellationToken) =>
        Ok(await mediator.Send(new RespondMarketplaceB2BRequestCommand { Id = id, Accept = true }, cancellationToken));

    [HttpPost("b2b-requests/{id:guid}/decline")]
    public async Task<IActionResult> Decline(Guid id, CancellationToken cancellationToken) =>
        Ok(await mediator.Send(new RespondMarketplaceB2BRequestCommand { Id = id, Accept = false }, cancellationToken));

    private BadRequestObjectResult Fail(string message) =>
        BadRequest(ApiResponse.Fail(message, HttpContext.TraceIdentifier));
}

/// <summary>
/// A customer's own orders and B2B requests: order, pay, cancel before it ships, review. Any signed-in
/// user — the customer screens come later; these let the business side be tried end to end.
/// </summary>
[ApiController]
[Route("api/v1/marketplace")]
public class CustomerMarketplaceOrdersController(ISender mediator) : ControllerBase
{
    [HttpGet("orders")]
    public async Task<IActionResult> GetMine([FromQuery] int page = 1, [FromQuery] int? pageSize = null, CancellationToken cancellationToken = default) =>
        Ok(await mediator.Send(new GetMyMarketplaceOrdersQuery { Page = page, PageSize = pageSize }, cancellationToken));

    [HttpPost("orders")]
    public async Task<IActionResult> Place([FromBody] PlaceMarketplaceOrderCommand command, CancellationToken cancellationToken) =>
        StatusCode(StatusCodes.Status201Created, await mediator.Send(command, cancellationToken));

    [HttpPost("orders/{id:guid}/payment")]
    public async Task<IActionResult> StartPayment(Guid id, CancellationToken cancellationToken) =>
        Ok(await mediator.Send(new StartMarketplaceOrderPaymentCommand { Id = id }, cancellationToken));

    [HttpPost("orders/{id:guid}/payment/confirm")]
    public async Task<IActionResult> ConfirmPayment(
        Guid id, [FromBody] CompleteMarketplaceOrderPaymentCommand command, CancellationToken cancellationToken)
    {
        command.Id = id;
        return Ok(await mediator.Send(command, cancellationToken));
    }

    [HttpPost("orders/{id:guid}/cancel")]
    public async Task<IActionResult> Cancel(Guid id, CancellationToken cancellationToken) =>
        Ok(await mediator.Send(new CancelMarketplaceOrderCommand { Id = id }, cancellationToken));

    [HttpPost("orders/{id:guid}/review")]
    public async Task<IActionResult> Review(Guid id, [FromBody] ReviewMarketplaceOrderCommand command, CancellationToken cancellationToken)
    {
        command.Id = id;
        return Ok(await mediator.Send(command, cancellationToken));
    }

    [HttpGet("b2b-requests")]
    public async Task<IActionResult> GetMyRequests([FromQuery] int page = 1, [FromQuery] int? pageSize = null, CancellationToken cancellationToken = default) =>
        Ok(await mediator.Send(new GetMyB2BRequestsQuery { Page = page, PageSize = pageSize }, cancellationToken));

    [HttpPost("b2b-requests")]
    public async Task<IActionResult> Ask([FromBody] CreateMarketplaceB2BRequestCommand command, CancellationToken cancellationToken) =>
        StatusCode(StatusCodes.Status201Created, await mediator.Send(command, cancellationToken));
}
