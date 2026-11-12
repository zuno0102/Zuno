using MediatR;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.RateLimiting;
using Microsoft.Extensions.Options;
using Zuno.Marketplace.Api.Common;
using Zuno.Marketplace.Application.Common;
using Zuno.Marketplace.Application.Posts;
using Zuno.Marketplace.Infrastructure.Services;

namespace Zuno.Marketplace.Api.Controllers;

/// <summary>A business's own Marketplace posts: list, add, edit, pause or close, remove, photos.</summary>
[ApiController]
[Route("api/v1/business/marketplace")]
[Authorize(Policy = MarketplacePolicies.BusinessOwner)]
public class BusinessMarketplaceController(
    ISender mediator,
    IOptions<MarketplaceFileStorageSettings> fileStorage,
    IOptions<MarketplaceSettings> settings) : ControllerBase
{
    [HttpGet]
    public async Task<IActionResult> GetMine(
        [FromQuery] int page = 1,
        [FromQuery] int? pageSize = null,
        [FromQuery] string? kind = null,
        [FromQuery] Guid? categoryId = null,
        [FromQuery] string? status = null,
        CancellationToken cancellationToken = default) =>
        Ok(await mediator.Send(
            new GetMyMarketplacePostsQuery { Page = page, PageSize = pageSize, Kind = kind, CategoryId = categoryId, Status = status },
            cancellationToken));

    /// <summary>The counts behind the Marketplace tiles, and the plan with how much of it is used.</summary>
    [HttpGet("summary")]
    public async Task<IActionResult> GetSummary(CancellationToken cancellationToken) =>
        Ok(await mediator.Send(new GetMyMarketplaceSummaryQuery(), cancellationToken));

    [HttpPost]
    public async Task<IActionResult> Create([FromBody] CreateMarketplacePostCommand command, CancellationToken cancellationToken) =>
        StatusCode(StatusCodes.Status201Created, await mediator.Send(command, cancellationToken));

    [HttpPut("{id:guid}")]
    public async Task<IActionResult> Update(Guid id, [FromBody] UpdateMarketplacePostCommand command, CancellationToken cancellationToken)
    {
        // The route decides which post; an id in the body is ignored.
        command.Id = id;
        return Ok(await mediator.Send(command, cancellationToken));
    }

    [HttpPatch("{id:guid}/status")]
    public async Task<IActionResult> ChangeStatus(
        Guid id, [FromBody] ChangeMarketplacePostStatusCommand command, CancellationToken cancellationToken)
    {
        command.Id = id;
        return Ok(await mediator.Send(command, cancellationToken));
    }

    /// <summary>Sets how many of a new item are left; 0 is out of stock.</summary>
    [HttpPatch("{id:guid}/stock")]
    public async Task<IActionResult> UpdateStock(
        Guid id, [FromBody] UpdateMarketplacePostStockCommand command, CancellationToken cancellationToken)
    {
        command.Id = id;
        return Ok(await mediator.Send(command, cancellationToken));
    }

    [HttpDelete("{id:guid}")]
    public async Task<IActionResult> Delete(Guid id, CancellationToken cancellationToken)
    {
        await mediator.Send(new DeleteMarketplacePostCommand { Id = id }, cancellationToken);
        return NoContent();
    }

    /// <summary>Refreshes the business's name, logo and verification from its Service profile.</summary>
    [HttpPost("profile/sync")]
    public async Task<IActionResult> SyncProfile(CancellationToken cancellationToken) =>
        Ok(await mediator.Send(new SyncMarketplaceBusinessCommand(), cancellationToken));

    [HttpPost("{id:guid}/images/{slot:int}")]
    [RequestSizeLimit(10_000_000)]
    [EnableRateLimiting(MarketplacePolicies.UploadPolicy)]
    public async Task<IActionResult> UploadImage(Guid id, int slot, IFormFile? file, CancellationToken cancellationToken)
    {
        var slots = settings.Value.ImageSlots;
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

        // Handed to the command, which saves it only after checking the post is the caller's.
        await using var stream = file.OpenReadStream();
        return Ok(await mediator.Send(
            new SetMarketplacePostImageCommand { PostId = id, SlotIndex = slot, Content = stream, FileExtension = extension },
            cancellationToken));
    }

    [HttpDelete("{id:guid}/images/{slot:int}")]
    public async Task<IActionResult> RemoveImage(Guid id, int slot, CancellationToken cancellationToken) =>
        Ok(await mediator.Send(new RemoveMarketplacePostImageCommand { PostId = id, SlotIndex = slot }, cancellationToken));

    private BadRequestObjectResult Fail(string message) =>
        BadRequest(ApiResponse.Fail(message, HttpContext.TraceIdentifier));
}
