namespace Zuno.Application.Modules.Notifications.DTOs;

/// <summary>One notification, as the list shows it.</summary>
public class NotificationDto
{
    public Guid Id { get; set; }

    /// <summary>
    /// What it is about, as a name — <c>JobInvitation</c>, <c>WagePaid</c>.
    /// </summary>
    /// <remarks>
    /// A string rather than the enum's number, matching how every other status leaves this API. The
    /// app uses it to pick the row's icon, never to decide where the row leads; that is
    /// <see cref="Target"/>'s job.
    /// </remarks>
    public string Kind { get; set; } = string.Empty;

    public string Title { get; set; } = string.Empty;

    public string Body { get; set; } = string.Empty;

    /// <summary>
    /// What tapping it opens — <c>Booking</c>, <c>Invitations</c>, <c>Payments</c>.
    /// </summary>
    /// <remarks>
    /// A thing, not a route. The server does not know the app's screen paths, so renaming one cannot
    /// break notifications already sitting on a phone.
    /// </remarks>
    public string Target { get; set; } = string.Empty;

    /// <summary>The id the target names, or null for targets that need none (a tab, a list).</summary>
    public Guid? TargetId { get; set; }

    public bool IsUnread { get; set; }

    public DateTimeOffset CreatedAt { get; set; }
}

/// <summary>The badge on the bell.</summary>
/// <remarks>
/// Its own tiny response rather than a bare integer, so a later addition — a per-kind breakdown, a
/// "since" marker — does not change the shape the app already parses.
/// </remarks>
public class NotificationCountDto
{
    public int UnreadCount { get; set; }
}
