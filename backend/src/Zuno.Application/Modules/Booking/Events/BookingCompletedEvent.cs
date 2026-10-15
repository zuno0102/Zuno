using MediatR;

namespace Zuno.Application.Modules.Booking.Events;

/// <summary>The whole order is finished — the last of the crew has marked their part done.</summary>
/// <remarks>
/// Carries the customer's user id as well as their email, for the same reason as
/// <see cref="BookingCreatedEvent"/>: a notification is addressed to a user.
/// </remarks>
public class BookingCompletedEvent(
    Guid bookingId,
    Guid customerUserId,
    string? customerEmail,
    string businessName) : INotification
{
    public Guid BookingId { get; } = bookingId;

    public Guid CustomerUserId { get; } = customerUserId;

    public string? CustomerEmail { get; } = customerEmail;

    public string BusinessName { get; } = businessName;
}
