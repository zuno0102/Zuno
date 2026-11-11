using Asp.Versioning;
using MediatR;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Zuno.Application.Modules.Catalog.Queries.GetDistricts;
using Zuno.Application.Modules.Catalog.Queries.GetNearestDistrict;

namespace Zuno.Api.Controllers;

[ApiController]
[ApiVersion("1.0")]
[Route("api/v{version:apiVersion}/districts")]
[AllowAnonymous]
public class DistrictsController(ISender mediator) : ControllerBase
{
    [HttpGet]
    public async Task<IActionResult> GetAll([FromQuery] List<Guid>? stateIds, CancellationToken cancellationToken)
    {
        var result = await mediator.Send(new GetDistrictsQuery { StateIds = stateIds }, cancellationToken);
        return Ok(result);
    }

    /// <summary>
    /// The district a point is in, by the nearest headquarters; null when it is too far from all of
    /// them. Anonymous like the list: the point is the caller's own and nothing is stored.
    /// </summary>
    [HttpGet("nearest")]
    public async Task<IActionResult> Nearest(
        [FromQuery] decimal latitude, [FromQuery] decimal longitude, CancellationToken cancellationToken) =>
        Ok(await mediator.Send(new GetNearestDistrictQuery(latitude, longitude), cancellationToken));
}
