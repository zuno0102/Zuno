using MediatR;
using Microsoft.AspNetCore.Mvc;
using Zuno.Marketplace.Application.Customer;

namespace Zuno.Marketplace.Api.Controllers;

/// <summary>
/// What customers browse: the Marketplace home, search, a post opened, and their wishlist. Any
/// signed-in user; only live posts of verified businesses are ever shown.
/// </summary>
[ApiController]
[Route("api/v1/marketplace")]
public class CustomerMarketplaceBrowseController(ISender mediator) : ControllerBase
{
    [HttpGet("home")]
    public async Task<IActionResult> Home(
        [FromQuery] List<Guid>? districtIds, [FromQuery] double? latitude, [FromQuery] double? longitude, CancellationToken cancellationToken) =>
        Ok(await mediator.Send(
            new GetMarketplaceHomeQuery { DistrictIds = districtIds ?? [], Latitude = latitude, Longitude = longitude },
            cancellationToken));

    [HttpGet("posts")]
    public async Task<IActionResult> Search([FromQuery] SearchMarketplacePostsQuery query, CancellationToken cancellationToken) =>
        Ok(await mediator.Send(query, cancellationToken));

    [HttpGet("posts/{id:guid}")]
    public async Task<IActionResult> Detail(Guid id, CancellationToken cancellationToken) =>
        Ok(await mediator.Send(new GetMarketplacePostDetailQuery { Id = id }, cancellationToken));

    [HttpGet("favourites")]
    public async Task<IActionResult> Favourites([FromQuery] int page = 1, [FromQuery] int? pageSize = null, CancellationToken cancellationToken = default) =>
        Ok(await mediator.Send(new GetMyFavouritesQuery { Page = page, PageSize = pageSize }, cancellationToken));

    /// <summary>Saves a post to the wishlist; saving it twice is the same as once.</summary>
    [HttpPut("favourites/{postId:guid}")]
    public async Task<IActionResult> Save(Guid postId, CancellationToken cancellationToken)
    {
        await mediator.Send(new AddFavouriteCommand { PostId = postId }, cancellationToken);
        return NoContent();
    }

    [HttpDelete("favourites/{postId:guid}")]
    public async Task<IActionResult> Remove(Guid postId, CancellationToken cancellationToken)
    {
        await mediator.Send(new RemoveFavouriteCommand { PostId = postId }, cancellationToken);
        return NoContent();
    }
}
