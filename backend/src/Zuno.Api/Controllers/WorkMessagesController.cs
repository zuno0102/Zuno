using Asp.Versioning;
using MediatR;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Zuno.Application.Modules.WorkChat.Commands.SendWorkMessage;
using Zuno.Application.Modules.WorkChat.Queries.GetMyWorkThreads;
using Zuno.Application.Modules.WorkChat.Queries.GetWorkMessages;

namespace Zuno.Api.Controllers;

/// <summary>
/// Messages between a business and the workers on its team.
/// </summary>
/// <remarks>
/// One controller for both sides, like booking messages: who is asking, and on which side, comes
/// from the team relationship in every handler, so the route never decides it. Customers have no
/// part here — the business is the middle man between customers and workers.
/// </remarks>
[ApiController]
[ApiVersion("1.0")]
[Route("api/v{version:apiVersion}/work-threads")]
[Authorize]
public class WorkMessagesController(ISender mediator) : ControllerBase
{
    /// <summary>Every business–worker conversation the signed-in user has.</summary>
    [HttpGet]
    public async Task<IActionResult> GetThreads(CancellationToken cancellationToken)
    {
        var result = await mediator.Send(new GetMyWorkThreadsQuery(), cancellationToken);
        return Ok(result);
    }

    /// <summary>
    /// One conversation, oldest first. <paramref name="counterpartId"/> is the other side's profile:
    /// the worker for a business, the business for a worker. Reading it marks the other side's
    /// messages read.
    /// </summary>
    [HttpGet("{counterpartId:guid}/messages")]
    public async Task<IActionResult> GetMessages(
        Guid counterpartId,
        CancellationToken cancellationToken)
    {
        var result = await mediator.Send(
            new GetWorkMessagesQuery(counterpartId),
            cancellationToken);
        return Ok(result);
    }

    [HttpPost("{counterpartId:guid}/messages")]
    public async Task<IActionResult> Send(
        Guid counterpartId,
        [FromBody] SendWorkMessageRequest request,
        CancellationToken cancellationToken)
    {
        var result = await mediator.Send(
            new SendWorkMessageCommand { CounterpartId = counterpartId, Body = request.Body },
            cancellationToken);
        return Ok(result);
    }
}

/// <summary>The body of a message. The other side comes from the route, the sender from the token.</summary>
public class SendWorkMessageRequest
{
    public string Body { get; set; } = string.Empty;
}
