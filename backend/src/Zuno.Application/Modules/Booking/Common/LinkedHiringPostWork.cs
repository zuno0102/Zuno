using Microsoft.EntityFrameworkCore;
using Zuno.Application.Common.Interfaces;

namespace Zuno.Application.Modules.Booking.Common;

/// <summary>
/// Keeps the hiring posts raised for an order in step with the order's own work.
/// </summary>
/// <remarks>
/// A crew hired through a post for an order works the order, but its job screens, schedules and —
/// above all — its pay run read the <em>post</em>. Paying refuses a post whose work is not marked
/// done, so an order finished without stamping its posts left that crew impossible to pay
/// ("Mark the work completed before paying the crew"). Every place an order starts or finishes
/// calls these, so the two can never drift apart again.
/// </remarks>
public static class LinkedHiringPostWork
{
    /// <summary>The order's work began: its posts' did too.</summary>
    public static async Task MarkStartedAsync(
        IApplicationDbContext dbContext,
        Guid bookingId,
        DateTimeOffset startedAt,
        CancellationToken cancellationToken)
    {
        var posts = await dbContext.HiringPosts
            .Where(p => p.BookingId == bookingId && p.WorkStartedAt == null)
            .ToListAsync(cancellationToken);

        foreach (var post in posts)
        {
            post.WorkStartedAt = startedAt;
        }
    }

    /// <summary>The order's work finished: its posts' did too.</summary>
    /// <param name="startedAt">When the order started, for any post never marked as started.</param>
    public static async Task MarkCompletedAsync(
        IApplicationDbContext dbContext,
        Guid bookingId,
        DateTimeOffset? startedAt,
        DateTimeOffset completedAt,
        CancellationToken cancellationToken)
    {
        var posts = await dbContext.HiringPosts
            .Where(p => p.BookingId == bookingId && p.WorkCompletedAt == null)
            .ToListAsync(cancellationToken);

        foreach (var post in posts)
        {
            post.WorkStartedAt ??= startedAt ?? completedAt;
            post.WorkCompletedAt = completedAt;
        }
    }
}
