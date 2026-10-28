using MediatR;
using Zuno.Application.Common.Interfaces;
using Zuno.Application.Modules.Notifications.Common;
using Zuno.Domain.Enums;

namespace Zuno.Application.Modules.WorkChat.Events;

/// <summary>A business–worker message, for the side that did not write it.</summary>
/// <param name="RecipientUserId">Who to tell.</param>
/// <param name="SenderProfileId">
/// The sender's profile — what the recipient opens the conversation with, so it is what the
/// notification points at.
/// </param>
/// <param name="SenderName">Who wrote it, as the recipient knows them.</param>
/// <param name="Body">What they wrote; clipped in the notification.</param>
public record WorkMessageSentEvent(
    Guid RecipientUserId,
    Guid SenderProfileId,
    string SenderName,
    string Body) : INotification;

/// <summary>
/// Titled with the sender's name and bodied with what they said, like a booking chat message.
/// Kept off the bell (see <see cref="BellNotifications"/>); the Messages list counts it instead.
/// </summary>
public class WorkMessageSentNotificationHandler(
    INotificationSender notifications) : INotificationHandler<WorkMessageSentEvent>
{
    public Task Handle(WorkMessageSentEvent notification, CancellationToken cancellationToken) =>
        notifications.NotifyAsync(
            notification.RecipientUserId,
            NotificationKind.WorkChatMessage,
            notification.SenderName,
            NotificationText.Preview(notification.Body),
            NotificationTarget.WorkChat,
            notification.SenderProfileId,
            cancellationToken);
}
