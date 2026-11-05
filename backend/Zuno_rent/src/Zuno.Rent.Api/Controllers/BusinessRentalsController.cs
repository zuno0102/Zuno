using MediatR;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.RateLimiting;
using Microsoft.Extensions.Options;
using Zuno.Rent.Api.Common;
using Zuno.Rent.Application.Common;
using Zuno.Rent.Application.Items;
using Zuno.Rent.Infrastructure.Services;

namespace Zuno.Rent.Api.Controllers;

/// <summary>A business's own rent items: list, add, edit, remove, photos and video.</summary>
[ApiController]
[Route("api/v1/business/rentals")]
[Authorize(Policy = RentPolicies.BusinessOwner)]
public class BusinessRentalsController(
    ISender mediator,
    IOptions<RentFileStorageSettings> fileStorage,
    IOptions<RentSettings> rentSettings) : ControllerBase
{
    [HttpGet]
    public async Task<IActionResult> GetMine(
        [FromQuery] int page = 1,
        [FromQuery] int? pageSize = null,
        [FromQuery] bool? isAvailable = null,
        CancellationToken cancellationToken = default) =>
        Ok(await mediator.Send(
            new GetMyRentalItemsQuery { Page = page, PageSize = pageSize, IsAvailable = isAvailable },
            cancellationToken));

    /// <summary>The counts behind the Rent tiles on the business home screen.</summary>
    [HttpGet("summary")]
    public async Task<IActionResult> GetSummary(CancellationToken cancellationToken) =>
        Ok(await mediator.Send(new GetMyRentalSummaryQuery(), cancellationToken));

    [HttpPost]
    public async Task<IActionResult> Create([FromBody] CreateRentalItemCommand command, CancellationToken cancellationToken) =>
        StatusCode(StatusCodes.Status201Created, await mediator.Send(command, cancellationToken));

    [HttpPut("{id:guid}")]
    public async Task<IActionResult> Update(Guid id, [FromBody] UpdateRentalItemCommand command, CancellationToken cancellationToken)
    {
        // The route decides which item; an id in the body is ignored.
        command.Id = id;
        return Ok(await mediator.Send(command, cancellationToken));
    }

    /// <summary>Refreshes the business's name, logo and verification from its Service profile, as customers see them.</summary>
    [HttpPost("profile/sync")]
    public async Task<IActionResult> SyncProfile(CancellationToken cancellationToken) =>
        Ok(await mediator.Send(new Application.Customer.SyncRentalBusinessCommand(), cancellationToken));

    /// <summary>
    /// The UPI ID the business's order QR is made from — taken from its Service profile, where the
    /// business sets it (PUT /business/profile/upi-id on the Service API).
    /// </summary>
    [HttpGet("payment-settings")]
    public async Task<IActionResult> GetPaymentSettings(CancellationToken cancellationToken) =>
        Ok(await mediator.Send(new Application.Orders.GetRentalPaymentSettingsQuery(), cancellationToken));

    /// <summary>Saves the UPI ID in Rent — only for the app before 1.10.1; newer apps use the profile.</summary>
    [HttpPut("payment-settings")]
    public async Task<IActionResult> UpdatePaymentSettings(
        [FromBody] Application.Orders.UpdateRentalPaymentSettingsCommand command, CancellationToken cancellationToken) =>
        Ok(await mediator.Send(command, cancellationToken));

    /// <summary>The Stock page: each item with in, out and total.</summary>
    [HttpGet("stock")]
    public async Task<IActionResult> GetStock(
        [FromQuery] int page = 1,
        [FromQuery] int? pageSize = null,
        CancellationToken cancellationToken = default) =>
        Ok(await mediator.Send(new GetMyRentalStockQuery { Page = page, PageSize = pageSize }, cancellationToken));

    /// <summary>How many a new order for these dates can take — the booking form shows it as it is filled in.</summary>
    [HttpGet("{id:guid}/availability")]
    public async Task<IActionResult> GetAvailability(
        Guid id,
        [FromQuery] DateTimeOffset start,
        [FromQuery] DateTimeOffset end,
        CancellationToken cancellationToken) =>
        Ok(await mediator.Send(
            new Application.Orders.GetRentalAvailabilityQuery { RentalItemId = id, StartDate = start, EndDate = end },
            cancellationToken));

    /// <summary>Where an item's pieces went: its orders, newest first.</summary>
    [HttpGet("{id:guid}/orders")]
    public async Task<IActionResult> GetOrders(
        Guid id,
        [FromQuery] int page = 1,
        [FromQuery] int? pageSize = null,
        CancellationToken cancellationToken = default) =>
        Ok(await mediator.Send(
            new GetRentalItemOrdersQuery { RentalItemId = id, Page = page, PageSize = pageSize },
            cancellationToken));

    /// <summary>The Stock page's quick change: quantity and availability only.</summary>
    [HttpPatch("{id:guid}/stock")]
    public async Task<IActionResult> UpdateStock(Guid id, [FromBody] UpdateRentalStockCommand command, CancellationToken cancellationToken)
    {
        // The route decides which item; an id in the body is ignored.
        command.Id = id;
        return Ok(await mediator.Send(command, cancellationToken));
    }

    [HttpDelete("{id:guid}")]
    public async Task<IActionResult> Delete(Guid id, CancellationToken cancellationToken)
    {
        await mediator.Send(new DeleteRentalItemCommand { Id = id }, cancellationToken);
        return NoContent();
    }

    [HttpPost("{id:guid}/images/{slot:int}")]
    [RequestSizeLimit(10_000_000)]
    [EnableRateLimiting(RentPolicies.UploadPolicy)]
    public async Task<IActionResult> UploadImage(Guid id, int slot, IFormFile? file, CancellationToken cancellationToken)
    {
        var slots = rentSettings.Value.ImageSlots;
        if (slot < 0 || slot >= slots)
        {
            return Fail($"Image slot must be between 0 and {slots - 1}.");
        }

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

        // Handed to the command, which saves it only after checking the item is the caller's.
        await using var stream = file.OpenReadStream();
        return Ok(await mediator.Send(
            new SetRentalItemImageCommand { RentalItemId = id, SlotIndex = slot, Content = stream, FileExtension = extension },
            cancellationToken));
    }

    [HttpDelete("{id:guid}/images/{slot:int}")]
    public async Task<IActionResult> RemoveImage(Guid id, int slot, CancellationToken cancellationToken) =>
        Ok(await mediator.Send(new RemoveRentalItemImageCommand { RentalItemId = id, SlotIndex = slot }, cancellationToken));

    [HttpPost("{id:guid}/video")]
    [RequestSizeLimit(30_000_000)]
    [EnableRateLimiting(RentPolicies.UploadPolicy)]
    public async Task<IActionResult> UploadVideo(Guid id, IFormFile? file, CancellationToken cancellationToken)
    {
        if (file is null || file.Length == 0)
        {
            return Fail("No file was uploaded.");
        }

        var max = fileStorage.Value.MaxVideoFileSizeBytes;
        if (file.Length > max)
        {
            return Fail($"Video must be {max / (1024 * 1024)}MB or smaller.");
        }

        var extension = await MediaUpload.VideoExtensionAsync(file, cancellationToken);
        if (extension is null)
        {
            return Fail(MediaUpload.VideoRule);
        }

        await using var stream = file.OpenReadStream();
        return Ok(await mediator.Send(
            new SetRentalItemVideoCommand { RentalItemId = id, Content = stream, FileExtension = extension },
            cancellationToken));
    }

    [HttpDelete("{id:guid}/video")]
    public async Task<IActionResult> RemoveVideo(Guid id, CancellationToken cancellationToken) =>
        Ok(await mediator.Send(new RemoveRentalItemVideoCommand { RentalItemId = id }, cancellationToken));

    private BadRequestObjectResult Fail(string message) =>
        BadRequest(ApiResponse.Fail(message, HttpContext.TraceIdentifier));
}
