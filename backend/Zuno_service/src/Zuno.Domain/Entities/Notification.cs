using Zuno.Domain.Common;
using Zuno.Domain.Enums;

namespace Zuno.Domain.Entities;

/// <summary>
/// Something that happened, told to the one person who was waiting on it.
/// </summary>
/// <remarks>
/// <para>
/// Addressed to a <see cref="UserId"/>, never to a role. The same person can be a worker on one job
/// and a customer on another, and what they need telling about follows the part they played, not the
/// row their account sits in.
/// </para>
/// <para>
/// <b>The words are written once, when it happens, and never recomputed.</b> A notification saying
/// "Boss T raised your wage to ₹1,100" has to keep saying that after the wage changes again — it is a
/// record of a moment, not a view over current state. This is why the title and body are stored
/// rather than rendered from the target at read time.
/// </para>
/// <para>
/// <see cref="Target"/> and <see cref="TargetId"/> are what make a tap land somewhere useful. They
/// name a thing, not a screen, so the app decides where that thing lives — see
/// <see cref="NotificationTarget"/>.
/// </para>
/// </remarks>
public class Notification : BaseEntity
{
    /// <summary>Who is being told.</summary>
    public Guid UserId { get; set; }

    public User User { get; set; } = null!;

    public NotificationKind Kind { get; set; }

    /// <summary>One line, the part that fits on a lock screen.</summary>
    public string Title { get; set; } = string.Empty;

    /// <summary>The detail under it. Empty where the title says everything.</summary>
    public string Body { get; set; } = string.Empty;

    public NotificationTarget Target { get; set; }

    /// <summary>
    /// The thing the target names, or <see cref="Guid.Empty"/> for targets that need no id.
    /// </summary>
    public Guid TargetId { get; set; }

    /// <summary>When they opened it, or null while it is still unread.</summary>
    public DateTimeOffset? ReadAt { get; set; }

    public bool IsUnread => ReadAt is null;
}
