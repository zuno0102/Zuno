using MediatR;
using Microsoft.Extensions.Logging;
using Zuno.Application.Common.Interfaces;

namespace Zuno.Application.Modules.Booking.Events;

/// <summary>
/// New-booking email delivery is a non-critical side effect — a failed or slow email
/// provider must never surface as a failed booking, so failures are logged and swallowed here.
/// </summary>
public class BookingCreatedEventHandler(
    IEmailService emailService,
    ILogger<BookingCreatedEventHandler> logger) : INotificationHandler<BookingCreatedEvent>
{
    public async Task Handle(BookingCreatedEvent notification, CancellationToken cancellationToken)
    {
        if (string.IsNullOrWhiteSpace(notification.BusinessOwnerEmail))
        {
            return;
        }

        try
        {
            await emailService.SendBookingCreatedEmailAsync(notification.BusinessOwnerEmail, notification.ServiceName, cancellationToken);
        }
        catch (Exception ex)
        {
            logger.LogWarning(ex, "Failed to send booking-created email for Booking {BookingId}. Booking was not affected.", notification.BookingId);
        }
    }
}
