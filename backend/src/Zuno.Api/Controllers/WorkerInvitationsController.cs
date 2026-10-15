using Asp.Versioning;
using MediatR;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Zuno.Api.Authorization;
using Zuno.Application.Modules.Business.Commands.RespondToWorkerInvitation;
using Zuno.Application.Modules.Business.Queries.GetMyWorkerInvitations;

namespace Zuno.Api.Controllers;

[ApiController]
[ApiVersion("1.0")]
[Route("api/v{version:apiVersion}/worker/invitations")]
[Authorize(Policy = AuthorizationPolicyNames.RequireWorkerRole)]
public class WorkerInvitationsController(ISender mediator) : ControllerBase
{
    [HttpGet]
    public async Task<IActionResult> GetMyInvitations(CancellationToken cancellationToken)
    {
        var result = await mediator.Send(new GetMyWorkerInvitationsQuery(), cancellationToken);
        return Ok(result);
    }

    [HttpPost("{id:guid}/respond")]
    public async Task<IActionResult> Respond(Guid id, [FromBody] RespondToWorkerInvitationRequest request, CancellationToken cancellationToken)
    {
        var result = await mediator.Send(
            new RespondToWorkerInvitationCommand { Id = id, Accept = request.Accept },
            cancellationToken);
        return Ok(result);
    }
}

public class RespondToWorkerInvitationRequest
{
    public bool Accept { get; set; }
}
