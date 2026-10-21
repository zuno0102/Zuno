namespace Zuno.Domain.Enums;

/// <summary>
/// What a notification points at, so the app can open it.
/// </summary>
/// <remarks>
/// A kind, not a URL. The server has no business knowing that a worker's jobs live behind
/// <c>/worker/job/:id</c> — rename that path and every notification already sitting on a phone would
/// point at nothing. The app maps a target to a screen, which keeps routing a client concern and
/// lets old notifications keep working after the screens move.
///
/// Each value is paired with one id on the notification. Where a target needs no id — a tab, a list
/// — the id is <see cref="Guid.Empty"/> and the app ignores it.
///
/// Values are persisted. Never renumber one; add to the end.
/// </remarks>
public enum NotificationTarget : short
{
    /// <summary>Nothing specific. Opens the person's dashboard.</summary>
    /// <remarks>
    /// The fallback, and deliberately almost unused. A notification that cannot say where it leads
    /// spends the one moment it had somebody's attention asking them to go and find it.
    /// </remarks>
    Home = 0,

    /// <summary>A booking, as its own side sees it — id is the booking.</summary>
    Booking = 1,

    /// <summary>A booking with its rating sheet open — id is the booking.</summary>
    BookingRating = 2,

    /// <summary>The conversation on a booking — id is the booking.</summary>
    BookingChat = 3,

    /// <summary>A hiring post — id is the post.</summary>
    HiringPost = 10,

    /// <summary>A hiring post's applicants, for the business — id is the post.</summary>
    HiringPostApplicants = 11,

    /// <summary>The worker's Invitations tab. No id.</summary>
    Invitations = 20,

    /// <summary>The worker's Find work tab. No id.</summary>
    FindWork = 21,

    /// <summary>The worker's My jobs tab. No id.</summary>
    MyJobs = 22,

    /// <summary>The worker's payments page. No id.</summary>
    Payments = 23,

    // 24 was Manage, a worker's management tab for a business-wide staff role. That idea is gone —
    // roles are per job now and only the Lead has any power, for one order, until the work is
    // finished — so nothing targets it. Kept out of use rather than renumbered: stored rows carry
    // these numbers, and reusing 24 would point an old notification somewhere new.

    /// <summary>The business's payouts for a post — id is the post.</summary>
    Payouts = 40,

    /// <summary>The signed-in person's own profile. No id.</summary>
    Profile = 50,

    /// <summary>
    /// A business–worker conversation — id is the other side's profile: the business profile for a
    /// worker reading it, the worker profile for a business.
    /// </summary>
    WorkChat = 60,
}
