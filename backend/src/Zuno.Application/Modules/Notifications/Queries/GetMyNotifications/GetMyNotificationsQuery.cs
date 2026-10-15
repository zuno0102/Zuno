using MediatR;
using Zuno.Application.Modules.Notifications.DTOs;

namespace Zuno.Application.Modules.Notifications.Queries.GetMyNotifications;

/// <summary>
/// The signed-in person's notifications, newest first.
/// </summary>
/// <remarks>
/// One list for all three roles. A notification is addressed to a user, not to a role, so there is
/// nothing for a customer and a worker version to differ about — and the same account can genuinely
/// receive both kinds.
/// </remarks>
public record GetMyNotificationsQuery : IRequest<List<NotificationDto>>
{
    /// <summary>How many to return. Capped by the handler.</summary>
    public int Take { get; init; } = 50;

    /// <summary>
    /// Return only what is still unread. Off by default, because the list is a history as much as
    /// an inbox — a notification read on one device must still be findable on another.
    /// </summary>
    public bool UnreadOnly { get; init; }
}
