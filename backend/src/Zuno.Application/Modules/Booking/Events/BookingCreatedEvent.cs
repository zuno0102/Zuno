using MediatR;

namespace Zuno.Application.Modules.Booking.Events;

/// <summary>A customer has placed an order, and the business has not answered it yet.</summary>
/// <remarks>
/// Carries the owner's user id as well as their email: the email is for the (still stubbed) mail
/// handler, and a notification is addressed to a user, which an email address cannot identify.
/// </remarks>
public class BookingCreatedEvent(
    Guid bookingId,
    Guid businessOwnerUserId,
    string? businessOwnerEmail,
    string serviceName,
    DateTimeOffset scheduledDate) : INotification
{
    public Guid BookingId { get; } = bookingId;

    public Guid BusinessOwnerUserId { get; } = businessOwnerUserId;

    public string? BusinessOwnerEmail { get; } = businessOwnerEmail;

    public string ServiceName { get; } = serviceName;

    public DateTimeOffset ScheduledDate { get; } = scheduledDate;
}
