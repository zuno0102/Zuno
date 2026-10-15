using MediatR;
using Zuno.Application.Modules.Notifications.DTOs;

namespace Zuno.Application.Modules.Notifications.Queries.GetUnreadNotificationCount;

/// <summary>
/// How many unread notifications the signed-in person has — the number on the bell.
/// </summary>
/// <remarks>
/// Separate from the list because it is asked for far more often: the badge lives above every tab
/// and is refreshed whenever the app comes back to the foreground, while the list is only fetched
/// when somebody opens it.
/// </remarks>
public record GetUnreadNotificationCountQuery : IRequest<NotificationCountDto>;
