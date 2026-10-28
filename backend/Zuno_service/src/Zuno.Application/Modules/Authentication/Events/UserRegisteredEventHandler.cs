using MediatR;
using Microsoft.Extensions.Logging;
using Zuno.Application.Common.Interfaces;

namespace Zuno.Application.Modules.Authentication.Events;

/// <summary>
/// Welcome-email delivery is a non-critical side effect of registration — a failed or slow
/// email provider must never surface as a failed registration, so failures are logged and swallowed here.
/// </summary>
public class UserRegisteredEventHandler(
    IEmailService emailService,
    ILogger<UserRegisteredEventHandler> logger) : INotificationHandler<UserRegisteredEvent>
{
    public async Task Handle(UserRegisteredEvent notification, CancellationToken cancellationToken)
    {
        if (string.IsNullOrWhiteSpace(notification.Email))
        {
            return;
        }

        try
        {
            await emailService.SendWelcomeEmailAsync(notification.Email, notification.FirstName, cancellationToken);
        }
        catch (Exception ex)
        {
            logger.LogWarning(
                ex,
                "Failed to send welcome email to user {UserId}. Registration was not affected.",
                notification.UserId);
        }
    }
}
