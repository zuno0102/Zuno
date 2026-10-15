using Asp.Versioning;
using MediatR;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Zuno.Application.Modules.Catalog.Queries.GetDistricts;

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
}
