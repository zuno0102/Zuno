using MediatR;
using Zuno.Domain.Enums;

namespace Zuno.Application.Modules.Notifications.Commands.MarkTargetNotificationsRead;

/// <summary>
/// Marks read everything the signed-in person was told about one particular thing.
/// </summary>
/// <remarks>
/// <para>
/// For the case the bell could not answer: somebody is told their booking was confirmed, opens that
/// booking and reads it, and the badge keeps counting a message about something they have just
/// dealt with. Opening the thing itself is as good as opening the notification — better, in fact,
/// because they saw the booking rather than a sentence about it.
/// </para>
/// <para>
/// Keyed on the target, not on a notification id, because the person who opened the booking never
/// saw a notification and the app has no id to send. Deliberately narrow: only notifications
/// pointing at <b>this</b> target, for <b>this</b> person. Clearing by kind, or because somebody
/// visited the tab, would quietly dismiss messages about bookings they never opened.
/// </para>
/// </remarks>
public class MarkTargetNotificationsReadCommand : IRequest<Unit>
{
    public NotificationTarget Target { get; set; }

    public Guid TargetId { get; set; }
}
