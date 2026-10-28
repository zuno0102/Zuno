using MediatR;

namespace Zuno.Application.Modules.Notifications.Commands.MarkAllNotificationsRead;

/// <summary>
/// Clears the badge: everything the signed-in person has unread becomes read.
/// </summary>
/// <remarks>
/// The rows stay. This is "I have seen these", not "delete these" — the list is also the record of
/// what happened, and the only copy once a lock-screen banner has been swiped away.
/// </remarks>
public class MarkAllNotificationsReadCommand : IRequest<Unit>;
