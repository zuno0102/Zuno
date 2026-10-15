using Asp.Versioning;
using MediatR;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Zuno.Api.Authorization;
using Zuno.Application.Modules.Worker.Queries.GetWorkerDashboard;

namespace Zuno.Api.Controllers;

/// <summary>
/// The worker's home screen: work done, money earned and owed, what is running and what is next.
/// </summary>
/// <remarks>
/// Its own controller rather than another action on the profile, mirroring the business dashboard:
/// the profile is one record, this is a whole screen assembled from several.
/// </remarks>
[ApiController]
[ApiVersion("1.0")]
[Route("api/v{version:apiVersion}/worker/dashboard")]
[Authorize(Policy = AuthorizationPolicyNames.RequireWorkerRole)]
public class WorkerDashboardController(ISender mediator) : ControllerBase
{
    [HttpGet]
    public async Task<IActionResult> GetDashboard(CancellationToken cancellationToken)
    {
        var result = await mediator.Send(new GetWorkerDashboardQuery(), cancellationToken);
        return Ok(result);
    }
}
