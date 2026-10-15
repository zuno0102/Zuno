using Microsoft.Extensions.Logging;
using Zuno.Application.Common.Interfaces;

namespace Zuno.Infrastructure.Services;

/// <summary>
/// Log-only stand-in for a real email provider. Swapping in SMTP/SendGrid/etc. later is a
/// one-file change behind IEmailService — no caller needs to change.
/// </summary>
public class EmailService(ILogger<EmailService> logger) : IEmailService
{
    public Task SendWelcomeEmailAsync(string toEmail, string firstName, CancellationToken cancellationToken)
    {
        logger.LogInformation("[EmailService:Welcome] To={ToEmail} FirstName={FirstName}", toEmail, firstName);
        return Task.CompletedTask;
    }

    public Task SendPasswordResetEmailAsync(string toEmail, string resetToken, CancellationToken cancellationToken)
    {
        logger.LogInformation("[EmailService:PasswordReset] To={ToEmail} ResetToken={ResetToken}", toEmail, resetToken);
        return Task.CompletedTask;
    }

    public Task SendWorkerInvitationEmailAsync(string toEmail, string businessName, CancellationToken cancellationToken)
    {
        logger.LogInformation("[EmailService:WorkerInvitation] To={ToEmail} BusinessName={BusinessName}", toEmail, businessName);
        return Task.CompletedTask;
    }

    public Task SendBookingCreatedEmailAsync(string toEmail, string serviceName, CancellationToken cancellationToken)
    {
        logger.LogInformation("[EmailService:BookingCreated] To={ToEmail} ServiceName={ServiceName}", toEmail, serviceName);
        return Task.CompletedTask;
    }

    public Task SendBookingCompletedEmailAsync(string toEmail, string businessName, CancellationToken cancellationToken)
    {
        logger.LogInformation("[EmailService:BookingCompleted] To={ToEmail} BusinessName={BusinessName}", toEmail, businessName);
        return Task.CompletedTask;
    }
}
