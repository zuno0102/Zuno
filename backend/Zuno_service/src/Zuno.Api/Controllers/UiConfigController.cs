using Asp.Versioning;
using MediatR;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Zuno.Application.Modules.Catalog.Queries.GetUiConfig;

namespace Zuno.Api.Controllers;

/// <summary>
/// Every label and colour the apps show, from the display_labels and theme_colors tables.
/// </summary>
/// <remarks>
/// Open to anyone: the sign-in screen is painted with these colours before anybody has signed in,
/// and none of it is private. Served from memory with an ETag, so an app that already has the
/// current version gets a 304 and no body — the common case on every launch.
/// </remarks>
[ApiController]
[ApiVersion("1.0")]
[AllowAnonymous]
[Route("api/v{version:apiVersion}/ui-config")]
public class UiConfigController(ISender mediator) : ControllerBase
{
    [HttpGet]
    public async Task<IActionResult> Get(CancellationToken cancellationToken)
    {
        var config = await mediator.Send(new GetUiConfigQuery(), cancellationToken);
        var etag = $"\"{config.Version}\"";

        Response.Headers.ETag = etag;
        Response.Headers.CacheControl = "no-cache";

        if (Request.Headers.IfNoneMatch.Contains(etag))
        {
            return StatusCode(StatusCodes.Status304NotModified);
        }

        return Ok(config);
    }
}
