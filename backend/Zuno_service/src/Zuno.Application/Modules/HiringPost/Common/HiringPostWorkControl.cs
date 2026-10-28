using Zuno.Domain.Enums;
using Zuno.Domain.ValueObjects;

namespace Zuno.Application.Modules.HiringPost.Common;

/// <summary>
/// Who may start and finish the work on one of the business's own events, and when its crew can be
/// given roles. The own-event twin of <see cref="Booking.Common.BookingWorkControl"/>, with the same
/// answer: the owner, or the Lead the owner named on that one job.
/// </summary>
/// <remarks>
/// <para>
/// Only for a post with no order behind it. A post raised for a customer order shares its crew with
/// the order, and its roles live on the order's assignments — so there is one place to set a role
/// and one answer to who leads. Here, <see cref="HoldsOwnRoles"/> is false for such a post.
/// </para>
/// <para>
/// As on an order, a role grants one thing only — starting and finishing the work. Wages, raises,
/// payouts and the crew stay with the owner.
/// </para>
/// </remarks>
public static class HiringPostWorkControl
{
    /// <summary>Whether this post keeps its crew's roles itself: one of the business's own events.</summary>
    public static bool HoldsOwnRoles(Domain.Entities.HiringPost post) => post.BookingId is null;

    /// <summary>
    /// Whether the crew can be given roles now: an own event whose work is not finished.
    /// </summary>
    /// <remarks>
    /// Before the day is fine — that is when a business plans who leads. After the work is marked
    /// done there is nothing left to run, so a role then would be a title attached to history.
    /// </remarks>
    public static bool CanHoldRoles(Domain.Entities.HiringPost post) =>
        HoldsOwnRoles(post) && post.WorkCompletedAt is null;

    /// <summary>
    /// Whether this user is the Lead on this own event: an accepted worker holding the Lead role.
    /// </summary>
    /// <remarks>
    /// Accepted, not merely offered — a worker who has not answered might still decline, and a lead
    /// who is not coming must not be able to say the work began.
    /// </remarks>
    public static bool IsLead(Domain.Entities.HiringPost post, Guid userId) =>
        HoldsOwnRoles(post)
        && post.Applications.Any(a =>
            a.WorkerProfile?.UserId == userId
            && a.ApplicationStatus == HiringPostApplicationStatus.Accepted
            && JobRole.GrantsWorkControl(a.Role));

    /// <summary>Whether this user may start or finish the work on this post.</summary>
    /// <param name="businessOwnerProfileId">The signed-in user's own business, or null for a worker.</param>
    public static bool MayMoveWork(
        Domain.Entities.HiringPost post,
        Guid userId,
        Guid? businessOwnerProfileId) =>
        (businessOwnerProfileId is { } ownerId && post.BusinessOwnerProfileId == ownerId)
        || IsLead(post, userId);

    /// <summary>
    /// Who the caller sees the post as: null for its owner (the full crew), or their own worker
    /// profile for a Lead — so a Lead starting the job is not handed every crew member's phone number.
    /// </summary>
    public static Guid? WorkerViewer(
        Domain.Entities.HiringPost post,
        Guid userId,
        Guid? businessOwnerProfileId) =>
        businessOwnerProfileId is { } ownerId && post.BusinessOwnerProfileId == ownerId
            ? null
            : post.Applications.FirstOrDefault(a => a.WorkerProfile?.UserId == userId)?.WorkerProfileId;
}
