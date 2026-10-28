using Zuno.Domain.Enums;

namespace Zuno.Application.Common.Interfaces;

/// <summary>
/// Tells one person that something happened.
/// </summary>
/// <remarks>
/// <para>
/// Non-critical side-effect boundary, on the same terms as <see cref="IEmailService"/>:
/// <b>implementations must never throw.</b> A notification is the news about a booking, never part
/// of it — a dead notification table must not roll back the booking that caused it. Every
/// implementation swallows and logs its own failures.
/// </para>
/// <para>
/// Called from event handlers, after the command that caused the event has already committed. The
/// words are passed in rather than composed here, because they have to name the business, the wage
/// and the date as they stood at that moment — see <see cref="Zuno.Domain.Entities.Notification"/>.
/// </para>
/// <para>
/// Later deliveries (push, and one day email) decorate this interface rather than replace it, so a
/// caller never knows or cares how many ways the news travelled.
/// </para>
/// </remarks>
public interface INotificationSender
{
    /// <param name="userId">Who is being told. Never the person who did the thing.</param>
    /// <param name="targetId">
    /// The thing <paramref name="target"/> names, or <see cref="Guid.Empty"/> for targets that need
    /// no id.
    /// </param>
    Task NotifyAsync(
        Guid userId,
        NotificationKind kind,
        string title,
        string body,
        NotificationTarget target,
        Guid targetId,
        CancellationToken cancellationToken);

    /// <summary>
    /// The same news to several people at once — a cancelled booking reaching every worker who was
    /// on it.
    /// </summary>
    /// <remarks>
    /// A real overload rather than a loop at the call site, so one real-world event is one round
    /// trip. Duplicate and empty ids are tolerated.
    /// </remarks>
    Task NotifyManyAsync(
        IEnumerable<Guid> userIds,
        NotificationKind kind,
        string title,
        string body,
        NotificationTarget target,
        Guid targetId,
        CancellationToken cancellationToken);
}
