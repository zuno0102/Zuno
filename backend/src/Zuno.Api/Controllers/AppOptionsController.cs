using Asp.Versioning;
using MediatR;
using Microsoft.AspNetCore.Mvc;
using Zuno.Application.Modules.Catalog.Queries.GetAppOptions;

namespace Zuno.Api.Controllers;

/// <summary>
/// The limits the apps' forms check before sending, read from the same platform settings the server
/// validates against. Signed-in users only: every form that uses them is behind sign-in.
/// </summary>
[ApiController]
[ApiVersion("1.0")]
[Route("api/v{version:apiVersion}/app-options")]
public class AppOptionsController(ISender mediator) : ControllerBase
{
    [HttpGet]
    public async Task<IActionResult> Get(CancellationToken cancellationToken)
    {
        var result = await mediator.Send(new GetAppOptionsQuery(), cancellationToken);
        return Ok(result);
    }
}
