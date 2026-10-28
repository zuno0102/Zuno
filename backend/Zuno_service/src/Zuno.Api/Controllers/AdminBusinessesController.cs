using Asp.Versioning;
using MediatR;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Zuno.Api.Authorization;
using Zuno.Application.Modules.Admin.Commands.SetBusinessVerification;
using Zuno.Application.Modules.Admin.Queries.GetBusinessesForReview;

namespace Zuno.Api.Controllers;

/// <summary>
/// Letting a business be found by customers, or refusing to.
/// </summary>
/// <remarks>
/// Every business registers as Pending and stays invisible until someone here approves it.
/// That gate was designed in from the start but had nothing behind it, so no business could
/// ever become visible — these are the endpoints that make the decision possible.
/// </remarks>
[ApiController]
[ApiVersion("1.0")]
[Route("api/v{version:apiVersion}/admin/businesses")]
[Authorize(Policy = AuthorizationPolicyNames.RequireSuperAdminRole)]
public class AdminBusinessesController(ISender mediator) : ControllerBase
{
    /// <param name="status">Pending, Verified or Rejected. Omit for all.</param>
    [HttpGet]
    public async Task<IActionResult> List(
        [FromQuery] string? status,
        CancellationToken cancellationToken)
    {
        var result = await mediator.Send(new GetBusinessesForReviewQuery(status), cancellationToken);
        return Ok(result);
    }

    /// <summary>Approves a business, making it and its services visible to customers.</summary>
    [HttpPost("{id:guid}/approve")]
    public async Task<IActionResult> Approve(Guid id, CancellationToken cancellationToken)
    {
        var result = await mediator.Send(
            new SetBusinessVerificationCommand(id, Approve: true), cancellationToken);
        return Ok(result);
    }

    /// <summary>Rejects a business, keeping it hidden from customers.</summary>
    [HttpPost("{id:guid}/reject")]
    public async Task<IActionResult> Reject(Guid id, CancellationToken cancellationToken)
    {
        var result = await mediator.Send(
            new SetBusinessVerificationCommand(id, Approve: false), cancellationToken);
        return Ok(result);
    }
}
