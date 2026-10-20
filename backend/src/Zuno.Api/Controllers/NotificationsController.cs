using Asp.Versioning;
using MediatR;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Zuno.Application.Modules.Notifications.Commands.MarkAllNotificationsRead;
using Zuno.Application.Modules.Notifications.Commands.MarkTargetNotificationsRead;
using Zuno.Application.Modules.Notifications.Commands.MarkNotificationRead;
using Zuno.Application.Modules.Notifications.Queries.GetMyNotifications;
using Zuno.Application.Modules.Notifications.Queries.GetUnreadNotificationCount;
using Zuno.Domain.Enums;

namespace Zuno.Api.Controllers;

/// <summary>
/// What the signed-in person has been told, and whether they have seen it.
/// </summary>
/// <remarks>
/// One controller for every role. A notification is addressed to a user, and the same account can be
/// a worker on one job and a customer on another — so there is nothing a customer, worker and
/// business copy of this would differ about except which rows came back, which the handler already
/// decides from the token.
///
/// Authorised for any signed-in user for the same reason: the only rule that matters is "is this
/// yours", and a role claim cannot answer it.
/// </remarks>
[ApiController]
[ApiVersion("1.0")]
[Route("api/v{version:apiVersion}/notifications")]
[Authorize]
public class NotificationsController(ISender mediator) : ControllerBase
{
    /// <summary>The signed-in person's notifications, newest first.</summary>
    [HttpGet]
    public async Task<IActionResult> GetMine(
        [FromQuery] int take = 50,
        [FromQuery] bool unreadOnly = false,
        [FromQuery] bool includeChat = false,
        CancellationToken cancellationToken = default)
    {
        var result = await mediator.Send(
            new GetMyNotificationsQuery
            {
                Take = take,
                UnreadOnly = unreadOnly,
                IncludeChat = includeChat,
            },
            cancellationToken);
        return Ok(result);
    }

    /// <summary>The number on the bell. Asked for on every app resume, so it stays its own call.</summary>
    [HttpGet("unread-count")]
    public async Task<IActionResult> GetUnreadCount(CancellationToken cancellationToken)
    {
        var result = await mediator.Send(new GetUnreadNotificationCountQuery(), cancellationToken);
        return Ok(result);
    }

    /// <summary>Marks one read — what tapping a row does on its way to opening the thing.</summary>
    [HttpPost("{notificationId:guid}/read")]
    public async Task<IActionResult> MarkRead(Guid notificationId, CancellationToken cancellationToken)
    {
        await mediator.Send(
            new MarkNotificationReadCommand { NotificationId = notificationId },
            cancellationToken);
        return NoContent();
    }

    /// <summary>Clears the badge. The notifications themselves stay in the list.</summary>
    [HttpPost("read-all")]
    public async Task<IActionResult> MarkAllRead(CancellationToken cancellationToken)
    {
        await mediator.Send(new MarkAllNotificationsReadCommand(), cancellationToken);
        return NoContent();
    }

    /// <summary>
    /// Marks read whatever this person was told about one particular thing.
    /// </summary>
    /// <remarks>
    /// Called when they open the thing itself — a booking, a hiring post — rather than the
    /// notification about it. Somebody who reads the booking has dealt with the message, and a
    /// badge that keeps counting it afterwards teaches people to ignore the badge.
    /// </remarks>
    [HttpPost("targets/{target}/{targetId:guid}/read")]
    public async Task<IActionResult> MarkTargetRead(
        NotificationTarget target,
        Guid targetId,
        CancellationToken cancellationToken)
    {
        await mediator.Send(
            new MarkTargetNotificationsReadCommand { Target = target, TargetId = targetId },
            cancellationToken);
        return NoContent();
    }
}
