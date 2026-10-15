using MediatR;
using Zuno.Application.Common.Interfaces;
using Zuno.Domain.Enums;

namespace Zuno.Application.Modules.Business.Events;

/// <summary>
/// Tells a worker a business wants them on its crew.
/// </summary>
/// <remarks>
/// <para>
/// A second handler on <see cref="WorkerInvitedEvent"/>, beside the email one. Neither knows the
/// other exists, which is the reason this event was published before notifications were a feature.
/// </para>
/// <para>
/// Opens the Invitations tab rather than a job, because this invitation is not about a job: it is
/// a standing relationship, and the tab is where the worker answers it.
/// </para>
/// <para>
/// No try/catch needed — <see cref="INotificationSender"/> swallows its own failures by contract,
/// so a notification can never fail the invitation that caused it.
/// </para>
/// </remarks>
public class WorkerInvitedNotificationHandler(
    INotificationSender notifications) : INotificationHandler<WorkerInvitedEvent>
{
    public Task Handle(WorkerInvitedEvent notification, CancellationToken cancellationToken) =>
        notifications.NotifyAsync(
            notification.WorkerUserId,
            NotificationKind.TeamInvitation,
            $"{notification.BusinessName} wants you on their team",
            "Accept to start getting their jobs.",
            NotificationTarget.Invitations,
            Guid.Empty,
            cancellationToken);
}
