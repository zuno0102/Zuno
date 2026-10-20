using Zuno.Domain.Entities;
using Zuno.Domain.Enums;

namespace Zuno.Application.Modules.Notifications.Common;

/// <summary>
/// Which notifications belong to the bell.
/// </summary>
/// <remarks>
/// <para>
/// Everything except chat. A new message already puts a number on the Chat tab, which is where
/// somebody goes to answer it — carrying it on the bell as well reports one message twice, in two
/// places, and the person clears it in one only to find the other still lit.
/// </para>
/// <para>
/// One rule in one place, because the three ways the bell is reached have to agree. The list, the
/// count and "read all" are separate queries, and a message that is counted but not listed, or
/// read by opening a list it was never in, is how the Chat tab lost its unread mark to a bell the
/// person had only glanced at.
/// </para>
/// </remarks>
public static class BellNotifications
{
    public static IQueryable<Notification> OnTheBell(this IQueryable<Notification> notifications) =>
        notifications.Where(n => n.Kind != NotificationKind.ChatMessage);
}
