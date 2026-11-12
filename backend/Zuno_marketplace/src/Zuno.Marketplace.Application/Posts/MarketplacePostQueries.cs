using FluentValidation;
using MediatR;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Options;
using Zuno.Marketplace.Application.Common;
using Zuno.Marketplace.Domain.Enums;

namespace Zuno.Marketplace.Application.Posts;

/// <summary>The signed-in business's posts, newest first, a page at a time.</summary>
public class GetMyMarketplacePostsQuery : IRequest<MarketplacePostPageDto>
{
    /// <summary>From 1.</summary>
    public int Page { get; set; } = 1;

    /// <summary>Null takes the configured default; anything above the configured maximum is capped.</summary>
    public int? PageSize { get; set; }

    /// <summary><c>Listing</c>, <c>FoodOffer</c> or <c>Advertisement</c>; null for all.</summary>
    public string? Kind { get; set; }

    /// <summary>One main category, e.g. Products; null for all.</summary>
    public Guid? CategoryId { get; set; }

    /// <summary>A shown status (<c>Active</c>, <c>Paused</c>, <c>Closed</c>, <c>Expired</c>); null for all.</summary>
    public string? Status { get; set; }

    /// <summary>True for the Stock page: only new products that keep a stock count and are not closed or sold.</summary>
    public bool? KeepsStock { get; set; }

    /// <summary>True for the Inactive tile: paused posts, and live products with a colour / size switched off.</summary>
    public bool? Inactive { get; set; }
}

public class GetMyMarketplacePostsQueryValidator : AbstractValidator<GetMyMarketplacePostsQuery>
{
    public GetMyMarketplacePostsQueryValidator()
    {
        RuleFor(x => x.Kind)
            .Must(k => k is null || Enum.TryParse<MarketplacePostKind>(k, true, out var v) && Enum.IsDefined(v))
            .WithMessage("Unknown post kind.");
        RuleFor(x => x.Status)
            .Must(s => s is null || Enum.TryParse<MarketplacePostStatus>(s, true, out var v) && Enum.IsDefined(v))
            .WithMessage("Unknown post status.");
    }
}

/// <summary>The counts behind the Marketplace tiles and the plan banner.</summary>
public class GetMyMarketplaceSummaryQuery : IRequest<MarketplaceSummaryDto>;

public class MarketplacePostQueryHandlers(
    ICurrentUser currentUser,
    IMarketplaceDbContext dbContext,
    MarketplaceReference reference,
    TimeProvider clock,
    IOptions<MarketplaceSettings> settings) :
    IRequestHandler<GetMyMarketplacePostsQuery, MarketplacePostPageDto>,
    IRequestHandler<GetMyMarketplaceSummaryQuery, MarketplaceSummaryDto>
{
    public async Task<MarketplacePostPageDto> Handle(GetMyMarketplacePostsQuery request, CancellationToken cancellationToken)
    {
        var ownerId = currentUser.OwnerId();
        var now = clock.GetUtcNow();
        var (page, pageSize) = MarketplaceQueries.Paging(request.Page, request.PageSize, settings.Value);

        var mine = dbContext.Posts.AsNoTracking().Where(p => p.OwnerUserId == ownerId);
        if (request.CategoryId is { } categoryId)
        {
            mine = mine.Where(p => p.CategoryId == categoryId);
        }

        if (Enum.TryParse<MarketplacePostKind>(request.Kind, true, out var kind))
        {
            mine = mine.Where(p => p.Kind == kind);
        }

        if (Enum.TryParse<MarketplacePostStatus>(request.Status, true, out var status))
        {
            mine = mine.WithShownStatus(status, now);
        }

        if (request.KeepsStock == true)
        {
            mine = mine.Where(p => p.Condition == MarketplaceItemCondition.New
                && p.Status != MarketplacePostStatus.Closed && p.Status != MarketplacePostStatus.Sold);
        }

        if (request.Inactive == true)
        {
            mine = mine.Where(MarketplaceQueries.IsInactive);
        }

        var totalCount = await mine.CountAsync(cancellationToken);

        // Served by the (owner_user_id, created_date) index; the joins run as one query per list.
        var posts = totalCount == 0
            ? []
            : await mine.WithCard()
                .OrderByDescending(p => p.CreatedDate)
                .ThenBy(p => p.Id)
                .Skip((page - 1) * pageSize)
                .Take(pageSize)
                .ToListAsync(cancellationToken);

        var transitions = await reference.TransitionsAsync(cancellationToken);
        return new MarketplacePostPageDto
        {
            Items = posts.Select(p => p.ToDto(now, transitions)).ToList(),
            Page = page,
            PageSize = pageSize,
            TotalCount = totalCount,
        };
    }

    public async Task<MarketplaceSummaryDto> Handle(GetMyMarketplaceSummaryQuery request, CancellationToken cancellationToken)
    {
        var ownerId = currentUser.OwnerId();
        var now = clock.GetUtcNow();

        // One aggregate over the owner's rows, a row per main category — not a list counted in the
        // app. Orders › Marketplace combines the category and status counts from these rows; the
        // totals are their sum (a handful of rows, added up here).
        var byCategory = await dbContext.Posts
            .AsNoTracking()
            .Where(p => p.OwnerUserId == ownerId)
            .GroupBy(p => p.CategoryId)
            .Select(g => new MarketplaceCategoryCountDto
            {
                CategoryId = g.Key,
                Active = g.Count(p => p.Status == MarketplacePostStatus.Active && (p.EndsAt == null || p.EndsAt > now)),
                Expired = g.Count(p => p.Status == MarketplacePostStatus.Active && p.EndsAt != null && p.EndsAt <= now),
                Paused = g.Count(p => p.Status == MarketplacePostStatus.Paused),
                Closed = g.Count(p => p.Status == MarketplacePostStatus.Closed),
                Sold = g.Count(p => p.Status == MarketplacePostStatus.Sold),
            })
            .ToListAsync(cancellationToken);

        var live = byCategory.Sum(c => c.Active);
        // A live product with a colour / size switched off is partly inactive: it is on the tile too.
        var withInactiveColour = await dbContext.Posts
            .AsNoTracking()
            .Where(p => p.OwnerUserId == ownerId && p.Status == MarketplacePostStatus.Active)
            .CountAsync(p => p.Variants.Any(v => !v.IsActive), cancellationToken);
        var (plan, endsAt) = await dbContext.CurrentAsync(ownerId, now, cancellationToken);
        return new MarketplaceSummaryDto
        {
            Active = live,
            Paused = byCategory.Sum(c => c.Paused),
            Inactive = byCategory.Sum(c => c.Paused) + withInactiveColour,
            Expired = byCategory.Sum(c => c.Expired),
            Closed = byCategory.Sum(c => c.Closed),
            Sold = byCategory.Sum(c => c.Sold),
            Categories = byCategory,
            Plan = new MarketplacePlanDto
            {
                Code = plan.Code,
                Name = plan.Name,
                Price = plan.Price,
                MaxActivePosts = plan.MaxActivePosts,
                UsedActivePosts = live,
                EndsAt = endsAt,
            },
        };
    }
}
