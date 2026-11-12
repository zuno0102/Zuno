using Microsoft.EntityFrameworkCore;
using Zuno.Marketplace.Domain.Entities;
using Zuno.Marketplace.Domain.Enums;
using Zuno.Marketplace.Domain.Exceptions;

namespace Zuno.Marketplace.Application.Common;

/// <summary>
/// Who is asking, whether a post is theirs, and the filters every read shares. The owner always comes
/// from the signed-in user's token, never from the request.
/// </summary>
internal static class MarketplaceQueries
{
    public static Guid OwnerId(this ICurrentUser currentUser) =>
        currentUser.UserId ?? throw new UnauthorizedAccessException("User is not authenticated.");

    /// <summary>Everything the post's card shows, tracked for changes — refused unless it is the caller's.</summary>
    public static async Task<MarketplacePost> OwnedPostAsync(
        this IMarketplaceDbContext dbContext, Guid postId, Guid ownerUserId, CancellationToken cancellationToken)
    {
        var post = await dbContext.Posts.WithCard()
            .FirstOrDefaultAsync(p => p.Id == postId, cancellationToken)
            ?? throw new EntityNotFoundException("Post", postId);

        if (post.OwnerUserId != ownerUserId)
        {
            throw new ForbiddenException("This post does not belong to your business.");
        }

        return post;
    }

    /// <summary>The joins one post card needs. The context splits them into one query per list.</summary>
    public static IQueryable<MarketplacePost> WithCard(this IQueryable<MarketplacePost> posts) =>
        posts
            .Include(p => p.Category)
            .Include(p => p.SubCategory)
            .Include(p => p.Media)
            .Include(p => p.District).ThenInclude(d => d.State);

    /// <summary>Posts that use a plan slot: Active and not yet ended.</summary>
    public static IQueryable<MarketplacePost> Live(this IQueryable<MarketplacePost> posts, DateTimeOffset now) =>
        posts.Where(p => p.Status == MarketplacePostStatus.Active && (p.EndsAt == null || p.EndsAt > now));

    /// <summary>Posts whose shown status is <paramref name="status"/> — Expired and Active split on the end time.</summary>
    public static IQueryable<MarketplacePost> WithShownStatus(
        this IQueryable<MarketplacePost> posts, MarketplacePostStatus status, DateTimeOffset now) =>
        status switch
        {
            MarketplacePostStatus.Active => posts.Live(now),
            MarketplacePostStatus.Expired => posts.Where(p =>
                p.Status == MarketplacePostStatus.Active && p.EndsAt != null && p.EndsAt <= now),
            _ => posts.Where(p => p.Status == status),
        };

    /// <summary>
    /// What a customer may see: live, started, in stock, in an active category, from a verified business.
    /// The customer screens (phase 2) read through this one rule.
    /// </summary>
    public static IQueryable<MarketplacePost> VisibleToCustomers(
        this IQueryable<MarketplacePost> posts, IQueryable<MarketplaceBusiness> businesses, DateTimeOffset now) =>
        posts.Live(now)
            .Where(p => p.StartsAt == null || p.StartsAt <= now)
            .Where(p => p.Category.IsActive)
            .Where(p => p.SubCategory == null || p.SubCategory.IsActive)
            .Where(p => p.Condition != MarketplaceItemCondition.New || p.Quantity > 0)
            .Where(p => businesses.Any(b => b.OwnerUserId == p.OwnerUserId && b.IsVerified));

    /// <summary>Clamps a page request to the configured limits.</summary>
    public static (int Page, int PageSize) Paging(int page, int? pageSize, MarketplaceSettings settings) =>
        (Math.Max(1, page), Math.Clamp(pageSize ?? settings.DefaultPageSize, 1, settings.MaxPageSize));

    /// <summary>Adds an item to a collection unless the very same object is already there.</summary>
    public static void AddIfMissing<T>(this ICollection<T> items, T item)
        where T : class
    {
        if (!items.Contains(item))
        {
            items.Add(item);
        }
    }
}
