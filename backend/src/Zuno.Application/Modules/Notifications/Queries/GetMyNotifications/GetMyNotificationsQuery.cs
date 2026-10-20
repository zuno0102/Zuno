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

    /// <summary>
    /// Include chat messages, which the bell leaves out.
    /// </summary>
    /// <remarks>
    /// Off by default, so the bell gets the bell's list. On for the one caller that is not the
    /// bell: the half that draws banners in the phone's own notification tray, which should
    /// announce a new message like anything else — it is the badge that double-counted them, not
    /// the banner.
    /// </remarks>
    public bool IncludeChat { get; init; }
}
