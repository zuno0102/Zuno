using Microsoft.Extensions.Logging;
using Zuno.Rent.Application.Common;

namespace Zuno.Rent.Infrastructure.Services;

/// <summary>
/// Sends no SMS: the code goes back to the app to show, so the whole verify-then-book flow runs before
/// an SMS provider is added. An SMS sender takes its place behind <see cref="IPhoneOtpSender"/>.
/// </summary>
public class TestPhoneOtpSender(ILogger<TestPhoneOtpSender> logger) : IPhoneOtpSender
{
    public bool ShowsCode => true;

    public Task SendAsync(string phone, string code, CancellationToken cancellationToken)
    {
        // The number masked and the code left out: logs are read by more people than the customer.
        logger.LogInformation("Test mobile code made for ******{LastFour}; no SMS sent.", phone[^4..]);
        return Task.CompletedTask;
    }
}
