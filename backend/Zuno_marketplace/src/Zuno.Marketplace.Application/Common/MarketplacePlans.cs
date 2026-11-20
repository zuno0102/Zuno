using Microsoft.EntityFrameworkCore;
using Zuno.Marketplace.Domain.Enums;

namespace Zuno.Marketplace.Application.Common;

/// <summary>
/// The plan checks Marketplace makes. How many posts a business may have live is the business's plan
/// over all three areas, held by the Service API and asked through <see cref="IServicePlanGate"/>;
/// the B2B buyer plan, which shows accepted sellers' contacts, stays here.
/// </summary>
internal static class MarketplacePlans
{
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

    /// <summary>How many of the business's posts are live now, leaving out <paramref name="exceptPostId"/>.</summary>
    public static Task<int> LiveCountAsync(
        this IMarketplaceDbContext dbContext, Guid ownerUserId, DateTimeOffset now, Guid? exceptPostId, CancellationToken cancellationToken) =>
        dbContext.Posts
            .Where(p => p.OwnerUserId == ownerUserId && p.Id != exceptPostId)
            .Live(now)
            .CountAsync(cancellationToken);

    /// <summary>Asks the business's plan before one more post goes live; <paramref name="postId"/> is the post going live.</summary>
    public static async Task EnsurePlanRoomAsync(
        this IMarketplaceDbContext dbContext,
        IServicePlanGate planGate,
        Guid ownerUserId,
        Guid? postId,
        DateTimeOffset now,
        CancellationToken cancellationToken)
    {
        var live = await dbContext.LiveCountAsync(ownerUserId, now, postId, cancellationToken);
        await planGate.EnsureCanAddAsync(live, cancellationToken);
    }
}
