using Microsoft.Extensions.Logging;
using Zuno.Application.Common.Interfaces;
using Zuno.Domain.Entities;
using Zuno.Domain.Enums;

namespace Zuno.Application.Common.Services;

/// <summary>
/// Writes the notification to our own table, which is what the in-app bell and list read.
/// </summary>
/// <remarks>
/// <para>
/// The base delivery, and the only one that survives being missed: a push banner dismissed on a lock
/// screen is gone for ever, so a push sender decorates this one rather than replacing it.
/// </para>
/// <para>
/// In the application layer, beside the other services that need nothing but
/// <see cref="IApplicationDbContext"/> — the same place <c>WorkerScheduleService</c> and
/// <c>BusinessReputationService</c> live. Infrastructure is for deliveries that leave the machine;
/// the FCM sender will go there, and will decorate this one.
/// </para>
/// <para>
/// Swallows everything, per the <see cref="INotificationSender"/> contract. Callers are event
/// handlers running after their command has committed; a failure here means somebody is not told
/// about a booking that definitely happened, which is a logged problem, not a rolled-back one.
/// </para>
/// </remarks>
public class DatabaseNotificationSender(
    IApplicationDbContext context,
    ILogger<DatabaseNotificationSender> logger) : INotificationSender
{
    // Matches NotificationConfiguration. Enforced here too so an unusually long business name
    // becomes a clipped notification rather than a swallowed DbUpdateException — i.e. nobody told.
    private const int MaxTitleLength = 200;
    private const int MaxBodyLength = 500;

    public Task NotifyAsync(
        Guid userId,
        NotificationKind kind,
        string title,
        string body,
        NotificationTarget target,
        Guid targetId,
        CancellationToken cancellationToken)
        => NotifyManyAsync([userId], kind, title, body, target, targetId, cancellationToken);

    public async Task NotifyManyAsync(
        IEnumerable<Guid> userIds,
        NotificationKind kind,
        string title,
        string body,
        NotificationTarget target,
        Guid targetId,
        CancellationToken cancellationToken)
    {
        // One row per person, however many times their id was passed in. Callers build recipient
        // lists out of assignments and applications, which can name the same person twice.
        var recipients = userIds
            .Where(id => id != Guid.Empty)
            .Distinct()
            .ToList();

        if (recipients.Count == 0)
        {
            return;
        }

        try
        {
            foreach (var userId in recipients)
            {
                context.Notifications.Add(new Notification
                {
                    UserId = userId,
                    Kind = kind,
                    Title = Clip(title, MaxTitleLength),
                    Body = Clip(body, MaxBodyLength),
                    Target = target,
                    TargetId = targetId,
                });
            }

            await context.SaveChangesAsync(cancellationToken);
        }
        catch (Exception exception)
        {
            logger.LogError(
                exception,
                "[Notifications] Failed to store {Kind} for {RecipientCount} recipient(s), target {Target}/{TargetId}",
                kind,
                recipients.Count,
                target,
                targetId);
        }
    }

    private static string Clip(string value, int maxLength)
    {
        if (string.IsNullOrEmpty(value))
        {
            return string.Empty;
        }

        return value.Length <= maxLength
            ? value
            : string.Concat(value.AsSpan(0, maxLength - 1).TrimEnd(), "…");
    }
}
