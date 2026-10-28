using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;
using Zuno.Application.Common.Interfaces;

namespace Zuno.Infrastructure.Services;

/// <summary>
/// Log-only stand-in for a real email provider. Swapping in SMTP/SendGrid/etc. later is a
/// one-file change behind IEmailService — no caller needs to change.
/// </summary>
/// <remarks>
/// <para>
/// Recipients are logged masked ("ab***@gmail.com"): logs are read by more people than the inbox
/// they stand in for, and a log of every user's address is a list worth stealing.
/// </para>
/// <para>
/// A password-reset token is written only in Development, where it is how a developer finishes a
/// reset. Anywhere else it was an account takeover for anyone who could read the logs — the token
/// resets any account, including the app owner's. Until a real provider is plugged in, a reset
/// requested in production therefore sends nothing; the request is still accepted and answered the
/// same way, so it reveals nothing about which accounts exist.
/// </para>
/// </remarks>
public class EmailService(ILogger<EmailService> logger, IHostEnvironment environment) : IEmailService
{
    public Task SendWelcomeEmailAsync(string toEmail, string firstName, CancellationToken cancellationToken)
    {
        logger.LogInformation("[EmailService:Welcome] To={ToEmail}", Mask(toEmail));
        return Task.CompletedTask;
    }

    public Task SendPasswordResetEmailAsync(string toEmail, string resetToken, CancellationToken cancellationToken)
    {
        if (environment.IsDevelopment())
        {
            logger.LogInformation(
                "[EmailService:PasswordReset] To={ToEmail} ResetToken={ResetToken}", Mask(toEmail), resetToken);
        }
        else
        {
            logger.LogWarning(
                "[EmailService:PasswordReset] No email provider is configured; the reset for {ToEmail} was not sent.",
                Mask(toEmail));
        }

        return Task.CompletedTask;
    }

    public Task SendWorkerInvitationEmailAsync(string toEmail, string businessName, CancellationToken cancellationToken)
    {
        logger.LogInformation("[EmailService:WorkerInvitation] To={ToEmail} BusinessName={BusinessName}", Mask(toEmail), businessName);
        return Task.CompletedTask;
    }

    public Task SendBookingCreatedEmailAsync(string toEmail, string serviceName, CancellationToken cancellationToken)
    {
        logger.LogInformation("[EmailService:BookingCreated] To={ToEmail} ServiceName={ServiceName}", Mask(toEmail), serviceName);
        return Task.CompletedTask;
    }

    public Task SendBookingCompletedEmailAsync(string toEmail, string businessName, CancellationToken cancellationToken)
    {
        logger.LogInformation("[EmailService:BookingCompleted] To={ToEmail} BusinessName={BusinessName}", Mask(toEmail), businessName);
        return Task.CompletedTask;
    }

    /// <summary>"abcdef@gmail.com" → "ab***@gmail.com": enough to tell two apart, not enough to write to.</summary>
    public static string Mask(string email)
    {
        var at = email.IndexOf('@');
        if (at <= 0)
        {
            return "***";
        }

        return email[..Math.Min(2, at)] + "***" + email[at..];
    }
}
