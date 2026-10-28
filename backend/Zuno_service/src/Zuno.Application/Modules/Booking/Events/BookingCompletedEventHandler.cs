using MediatR;
using Microsoft.Extensions.Logging;
using Zuno.Application.Common.Interfaces;

namespace Zuno.Application.Modules.Booking.Events;

/// <summary>
/// Completion-email delivery (prompting the customer to rate) is a non-critical side effect —
/// a failed or slow email provider must never surface as a failed completion.
/// </summary>
public class BookingCompletedEventHandler(
    IEmailService emailService,
    ILogger<BookingCompletedEventHandler> logger) : INotificationHandler<BookingCompletedEvent>
{
    public async Task Handle(BookingCompletedEvent notification, CancellationToken cancellationToken)
    {
        if (string.IsNullOrWhiteSpace(notification.CustomerEmail))
        {
            return;
        }

        try
        {
            await emailService.SendBookingCompletedEmailAsync(notification.CustomerEmail, notification.BusinessName, cancellationToken);
        }
        catch (Exception ex)
        {
            logger.LogWarning(ex, "Failed to send booking-completed email for Booking {BookingId}. Completion was not affected.", notification.BookingId);
        }
    }
}
