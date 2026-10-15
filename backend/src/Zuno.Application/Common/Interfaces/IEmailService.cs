namespace Zuno.Application.Common.Interfaces;

/// <summary>
/// Non-critical side-effect boundary. Implementations must never throw — a failed
/// send must never block the caller's transaction (see UserRegisteredEventHandler).
/// </summary>
public interface IEmailService
{
    Task SendWelcomeEmailAsync(string toEmail, string firstName, CancellationToken cancellationToken);

    Task SendPasswordResetEmailAsync(string toEmail, string resetToken, CancellationToken cancellationToken);

    Task SendWorkerInvitationEmailAsync(string toEmail, string businessName, CancellationToken cancellationToken);

    Task SendBookingCreatedEmailAsync(string toEmail, string serviceName, CancellationToken cancellationToken);

    Task SendBookingCompletedEmailAsync(string toEmail, string businessName, CancellationToken cancellationToken);
}
