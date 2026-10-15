using Asp.Versioning;
using MediatR;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Zuno.Api.Authorization;
using Zuno.Application.Modules.Worker.Commands.UpdateMyWorkerProfile;
using Zuno.Application.Modules.Worker.Queries.GetMyWorkerProfile;

namespace Zuno.Api.Controllers;

/// <summary>The worker's own profile: earnings, work record, and payout setup.</summary>
[ApiController]
[ApiVersion("1.0")]
[Route("api/v{version:apiVersion}/worker/profile")]
[Authorize(Policy = AuthorizationPolicyNames.RequireWorkerRole)]
public class WorkerProfileController(ISender mediator) : ControllerBase
{
    [HttpGet]
    public async Task<IActionResult> GetMyProfile(CancellationToken cancellationToken)
    {
        var result = await mediator.Send(new GetMyWorkerProfileQuery(), cancellationToken);
        return Ok(result);
    }

    /// <summary>
    /// Changes the worker's own contact details, payout address, rate and experience.
    /// </summary>
    /// <remarks>
    /// Every field is optional and an omitted one is left as it was, so this is a patch in spirit
    /// even though it is a PUT — the form does not necessarily hold the whole profile, and a blank
    /// field must not erase the only UPI a worker has.
    /// </remarks>
    [HttpPut]
    public async Task<IActionResult> UpdateMyProfile(
        UpdateMyWorkerProfileCommand command,
        CancellationToken cancellationToken)
    {
        var result = await mediator.Send(command, cancellationToken);
        return Ok(result);
    }
}
