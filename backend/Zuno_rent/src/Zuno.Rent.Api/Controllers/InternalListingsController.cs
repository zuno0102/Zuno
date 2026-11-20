using MediatR;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Zuno.Rent.Api.Common;
using Zuno.Rent.Application.Items;

namespace Zuno.Rent.Api.Controllers;

/// <summary>
/// For the Service API only, with the key the APIs share: a business's live rent items for its plan,
/// and pausing or resuming them when a plan ends or is renewed. No sign-in; without the key it is 404.
/// </summary>
[ApiController]
[Route("api/v1/internal/owners/{ownerUserId:guid}")]
[AllowAnonymous]
[InternalApiKey]
[ApiExplorerSettings(IgnoreApi = true)]
public class InternalListingsController(ISender mediator) : ControllerBase
{
    [HttpGet("live-listings")]
    public async Task<IActionResult> Live(Guid ownerUserId, CancellationToken cancellationToken) =>
        Ok(await mediator.Send(new GetLiveListingsQuery(ownerUserId), cancellationToken));

    [HttpPost("pause")]
    public async Task<IActionResult> Pause(Guid ownerUserId, [FromBody] IdsRequest request, CancellationToken cancellationToken)
    {
        await mediator.Send(new SetListingsLiveCommand(ownerUserId, request.Ids, Live: false), cancellationToken);
        return NoContent();
    }

    [HttpPost("resume")]
    public async Task<IActionResult> Resume(Guid ownerUserId, [FromBody] IdsRequest request, CancellationToken cancellationToken)
    {
        await mediator.Send(new SetListingsLiveCommand(ownerUserId, request.Ids, Live: true), cancellationToken);
        return NoContent();
    }

    public record IdsRequest(List<Guid> Ids);
}
