using MediatR;
using Microsoft.Extensions.Logging;
using Zuno.Application.Common.Interfaces;

namespace Zuno.Application.Modules.Business.Events;

/// <summary>
/// Invitation-email delivery is a non-critical side effect — a failed or slow email provider
/// must never surface as a failed invitation, so failures are logged and swallowed here.
/// </summary>
public class WorkerInvitedEventHandler(
    IEmailService emailService,
    ILogger<WorkerInvitedEventHandler> logger) : INotificationHandler<WorkerInvitedEvent>
{
    public async Task Handle(WorkerInvitedEvent notification, CancellationToken cancellationToken)
    {
        if (string.IsNullOrWhiteSpace(notification.WorkerEmail))
        {
            return;
        }

        try
        {
            await emailService.SendWorkerInvitationEmailAsync(notification.WorkerEmail, notification.BusinessName, cancellationToken);
        }
        catch (Exception ex)
        {
            logger.LogWarning(
                ex,
                "Failed to send worker invitation email for BusinessWorker {BusinessWorkerId}. Invitation was not affected.",
                notification.BusinessWorkerId);
        }
    }
}
