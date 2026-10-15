using Asp.Versioning;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.RateLimiting;
using Zuno.Api.RateLimiting;
using Zuno.Application.Common.Interfaces;

namespace Zuno.Api.Controllers;

/// <summary>
/// Looking a place up by name, so somebody can say where they are or where a job is.
/// </summary>
/// <remarks>
/// Open to any signed-in role: a worker uses it to search from somewhere other than where they are
/// standing, and a business uses it to pin a job. Rate limited because every call reaches an outside
/// provider on whatever text arrives.
/// </remarks>
[ApiController]
[ApiVersion("1.0")]
[Route("api/v{version:apiVersion}/places")]
[Authorize]
[EnableRateLimiting(RateLimiterExtensions.PlaceSearchPolicy)]
public class PlacesController(
    IPlaceSearchService placeSearch,
    IRouteService routeService) : ControllerBase
{
    /// <summary>Places matching <paramref name="q"/>, best match first.</summary>
    /// <remarks>
    /// Returns an empty list rather than an error for a short or unmatched query: an empty result is
    /// the honest answer, and it leaves the caller able to carry on.
    /// </remarks>
    [HttpGet("search")]
    public async Task<IActionResult> Search(
        [FromQuery] string q,
        CancellationToken cancellationToken)
    {
        var results = await placeSearch.SearchAsync(q ?? string.Empty, cancellationToken);
        return Ok(results);
    }

    /// <summary>What the place at these coordinates is called.</summary>
    /// <remarks>
    /// Used right after a worker shares their location, so the screen can name where they are rather
    /// than saying "your current location". Returns 204 when the spot cannot be named, which is not an
    /// error — the caller carries on with the coordinates it already has.
    /// </remarks>
    [HttpGet("reverse")]
    public async Task<IActionResult> Reverse(
        [FromQuery] double latitude,
        [FromQuery] double longitude,
        CancellationToken cancellationToken)
    {
        var place = await placeSearch.ReverseAsync(latitude, longitude, cancellationToken);
        return place is null ? NoContent() : Ok(place);
    }

    /// <summary>The road route between two points, for drawing the way to a job.</summary>
    /// <remarks>
    /// Returns 204 when no road route exists — across water, for instance — which the caller treats
    /// as "draw the straight line instead" rather than as an error.
    /// </remarks>
    [HttpGet("route")]
    public async Task<IActionResult> Route(
        [FromQuery] double fromLatitude,
        [FromQuery] double fromLongitude,
        [FromQuery] double toLatitude,
        [FromQuery] double toLongitude,
        CancellationToken cancellationToken)
    {
        var route = await routeService.GetRouteAsync(
            fromLatitude,
            fromLongitude,
            toLatitude,
            toLongitude,
            cancellationToken);

        return route is null ? NoContent() : Ok(route);
    }
}
