using Asp.Versioning;
using MediatR;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Zuno.Api.Authorization;
using Zuno.Application.Modules.HiringPost.Commands.ApplyToHiringPost;
using Zuno.Api.Contracts;
using Zuno.Application.Modules.HiringPost.Commands.CompleteHiringPostWork;
using Zuno.Application.Modules.HiringPost.Commands.RespondToHiringPostOffer;
using Zuno.Application.Modules.HiringPost.Commands.StartHiringPostWork;
using Zuno.Application.Modules.HiringPost.Commands.RespondToPayment;
using Zuno.Application.Modules.HiringPost.Queries.GetHiringBusiness;
using Zuno.Application.Modules.HiringPost.Queries.GetMyJobOffers;
using Zuno.Application.Modules.HiringPost.Queries.GetMyPostJobs;
using Zuno.Application.Modules.HiringPost.Queries.GetOpenHiringPosts;

namespace Zuno.Api.Controllers;

[ApiController]
[ApiVersion("1.0")]
[Route("api/v{version:apiVersion}/worker/hiring-posts")]
[Authorize(Policy = AuthorizationPolicyNames.RequireWorkerRole)]
public class WorkerHiringPostsController(ISender mediator) : ControllerBase
{
    /// <summary>
    /// Jobs a worker can see, optionally only the ones near them.
    /// </summary>
    /// <remarks>
    /// Called with no parameters this returns what it always did, so a worker who has not shared a
    /// location loses nothing.
    /// </remarks>
    [HttpGet]
    public async Task<IActionResult> GetOpenPosts(
        [FromQuery] GetOpenHiringPostsQuery query,
        CancellationToken cancellationToken)
    {
        var result = await mediator.Send(query, cancellationToken);
        return Ok(result);
    }
    /// <summary>Jobs this worker has been invited onto, still waiting on their answer.</summary>
    /// <remarks>
    /// Separate from the feed above because an offer is not something the worker searched for. It
    /// must not be hidden by a distance filter they set last week, nor fall off the end of a page.
    /// </remarks>
    [HttpGet("offers")]
    public async Task<IActionResult> GetMyOffers(CancellationToken cancellationToken)
    {
        var result = await mediator.Send(new GetMyJobOffersQuery(), cancellationToken);
        return Ok(result);
    }

    /// <summary>Work this worker took through a hiring post, past and future.</summary>
    /// <remarks>
    /// My jobs is fed by <c>/worker/jobs</c>, which returns customer bookings only. Without this a
    /// job taken through a post shows on the dashboard and nowhere a worker can act on it.
    /// </remarks>
    [HttpGet("mine")]
    public async Task<IActionResult> GetMyPostJobs(CancellationToken cancellationToken)
    {
        var result = await mediator.Send(new GetMyPostJobsQuery(), cancellationToken);
        return Ok(result);
    }

    /// <summary>A hiring business as a worker sees it: what it pays, and whether it pays.</summary>
    [HttpGet("businesses/{businessId:guid}")]
    public async Task<IActionResult> GetBusiness(
        Guid businessId,
        [FromQuery] double? latitude,
        [FromQuery] double? longitude,
        CancellationToken cancellationToken = default)
    {
        var result = await mediator.Send(
            new GetHiringBusinessQuery(businessId, latitude, longitude),
            cancellationToken);
        return Ok(result);
    }

    [HttpPost("{id:guid}/apply")]
    public async Task<IActionResult> Apply(Guid id, CancellationToken cancellationToken)
    {
        var result = await mediator.Send(new ApplyToHiringPostCommand { HiringPostId = id }, cancellationToken);
        return Ok(result);
    }

    /// <summary>
    /// Accepts or declines an offer the business has made. The vacancy is only filled once
    /// the worker accepts here; declining releases the slot back to the post.
    /// </summary>
    [HttpPost("applications/{applicationId:guid}/respond")]
    public async Task<IActionResult> RespondToOffer(
        Guid applicationId,
        RespondToHiringPostOfferCommand command,
        CancellationToken cancellationToken)
    {
        command.ApplicationId = applicationId;
        var result = await mediator.Send(command, cancellationToken);
        return Ok(result);
    }

    // The Lead on one of a business's own events moving its work on. Here, not on the business
    // controller, because that one is closed to the BusinessOwner role and a Lead is a worker.
    // The handlers refuse anybody who is not that job's Lead (HiringPostWorkControl).

    /// <summary>The own event's Lead saying the work has begun.</summary>
    [HttpPost("{id:guid}/start-work")]
    public async Task<IActionResult> StartWork(Guid id, CancellationToken cancellationToken)
    {
        var result = await mediator.Send(new StartHiringPostWorkCommand { HiringPostId = id }, cancellationToken);
        return Ok(result);
    }

    /// <summary>The own event's Lead marking the work completed.</summary>
    [HttpPost("{id:guid}/complete-work")]
    public async Task<IActionResult> CompleteWork(Guid id, CancellationToken cancellationToken)
    {
        var result = await mediator.Send(new CompleteHiringPostWorkCommand { HiringPostId = id }, cancellationToken);
        return Ok(result);
    }

    /// <summary>
    /// Confirms wages arrived, or reports that they never did.
    /// </summary>
    /// <remarks>
    /// A business marking someone paid is only its own word, and a provider reporting success says
    /// the instruction was accepted rather than that money landed. The worker is the one who can
    /// actually tell — so this is what closes a payment, and a report here is what flags a business.
    /// </remarks>
    [HttpPost("applications/{applicationId:guid}/payment-response")]
    public async Task<IActionResult> RespondToPayment(
        Guid applicationId,
        [FromBody] RespondToPaymentRequest request,
        CancellationToken cancellationToken)
    {
        await mediator.Send(
            new RespondToPaymentCommand(applicationId, request.Received, request.DisputeReason),
            cancellationToken);
        return NoContent();
    }
}
