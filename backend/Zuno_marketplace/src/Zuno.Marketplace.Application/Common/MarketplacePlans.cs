using Microsoft.EntityFrameworkCore;
using Zuno.Marketplace.Domain.Entities;
using Zuno.Marketplace.Domain.Enums;
using Zuno.Marketplace.Domain.Exceptions;

namespace Zuno.Marketplace.Application.Common;

/// <summary>
/// Which plan a business is on and whether it has room for one more live post. The limit is the
/// plan row's, never a number in code: the free plan's one post today, more when paid plans come.
/// </summary>
internal static class MarketplacePlans
{
    /// <summary>The plan the business has taken and is still running, else the default plan.</summary>
    public static async Task<(MarketplacePlan Plan, DateTimeOffset? EndsAt)> CurrentAsync(
        this IMarketplaceDbContext dbContext, Guid ownerUserId, DateTimeOffset now, CancellationToken cancellationToken)
    {
        var taken = await dbContext.BusinessPlans
            .AsNoTracking()
            .Include(b => b.Plan)
            .Where(b => b.OwnerUserId == ownerUserId && b.StartsAt <= now && (b.EndsAt == null || b.EndsAt > now))
            .Where(b => b.Plan.IsActive && b.Plan.Purpose == MarketplacePlanPurpose.Posting)
            .OrderByDescending(b => b.StartsAt)
            .FirstOrDefaultAsync(cancellationToken);
        if (taken is not null)
        {
            return (taken.Plan, taken.EndsAt);
        }

        var fallback = await dbContext.Plans.AsNoTracking()
            .FirstOrDefaultAsync(p => p.IsDefault && p.IsActive && p.Purpose == MarketplacePlanPurpose.Posting, cancellationToken)
            ?? throw new InvalidOperationException("No default Marketplace plan is set up.");
        return (fallback, null);
    }

    /// <summary>Whether <paramref name="userId"/> has a B2B buyer plan running now: it shows accepted sellers' contacts.</summary>
    public static Task<bool> HasB2BBuyerPlanAsync(
        this IMarketplaceDbContext dbContext, Guid userId, DateTimeOffset now, CancellationToken cancellationToken) =>
        dbContext.BusinessPlans.AnyAsync(
            b => b.OwnerUserId == userId
                && b.Plan.Purpose == MarketplacePlanPurpose.B2BBuyer
                && b.Plan.IsActive
                && b.StartsAt <= now
                && (b.EndsAt == null || b.EndsAt > now),
            cancellationToken);

    /// <summary>How many of the business's posts use a plan slot now, leaving out <paramref name="exceptPostId"/>.</summary>
    public static Task<int> LiveCountAsync(
        this IMarketplaceDbContext dbContext, Guid ownerUserId, DateTimeOffset now, Guid? exceptPostId, CancellationToken cancellationToken) =>
        dbContext.Posts
            .Where(p => p.OwnerUserId == ownerUserId && p.Id != exceptPostId)
            .Live(now)
            .CountAsync(cancellationToken);

    /// <summary>Refuses a post going live when the plan's slots are all used by the business's other posts.</summary>
    public static async Task EnsureRoomAsync(
        this IMarketplaceDbContext dbContext, Guid ownerUserId, Guid? postId, DateTimeOffset now, CancellationToken cancellationToken)
    {
        var (plan, _) = await dbContext.CurrentAsync(ownerUserId, now, cancellationToken);
        var used = await dbContext.LiveCountAsync(ownerUserId, now, postId, cancellationToken);
        if (used >= plan.MaxActivePosts)
        {
            throw new DomainException(
                $"Your {plan.Name} plan allows {plan.MaxActivePosts} active post{(plan.MaxActivePosts == 1 ? string.Empty : "s")}. " +
                "Pause, close or remove one to put up another.");
        }
    }
}
