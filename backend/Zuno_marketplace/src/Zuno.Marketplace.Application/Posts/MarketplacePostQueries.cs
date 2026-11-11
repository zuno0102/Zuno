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

    /// <summary>A shown status (<c>Active</c>, <c>Paused</c>, <c>Closed</c>, <c>Expired</c>); null for all.</summary>
    public string? Status { get; set; }
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
        if (Enum.TryParse<MarketplacePostKind>(request.Kind, true, out var kind))
        {
            mine = mine.Where(p => p.Kind == kind);
        }

        if (Enum.TryParse<MarketplacePostStatus>(request.Status, true, out var status))
        {
            mine = mine.WithShownStatus(status, now);
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

        // One aggregate over the owner's rows, not a list counted in the app.
        var totals = await dbContext.Posts
            .AsNoTracking()
            .Where(p => p.OwnerUserId == ownerId)
            .GroupBy(_ => 1)
            .Select(g => new
            {
                Live = g.Count(p => p.Status == MarketplacePostStatus.Active && (p.EndsAt == null || p.EndsAt > now)),
                Expired = g.Count(p => p.Status == MarketplacePostStatus.Active && p.EndsAt != null && p.EndsAt <= now),
                Paused = g.Count(p => p.Status == MarketplacePostStatus.Paused),
                Closed = g.Count(p => p.Status == MarketplacePostStatus.Closed),
            })
            .FirstOrDefaultAsync(cancellationToken);

        var (plan, endsAt) = await dbContext.CurrentAsync(ownerId, now, cancellationToken);
        return new MarketplaceSummaryDto
        {
            Active = totals?.Live ?? 0,
            Paused = totals?.Paused ?? 0,
            Expired = totals?.Expired ?? 0,
            Closed = totals?.Closed ?? 0,
            Plan = new MarketplacePlanDto
            {
                Code = plan.Code,
                Name = plan.Name,
                Price = plan.Price,
                MaxActivePosts = plan.MaxActivePosts,
                UsedActivePosts = totals?.Live ?? 0,
                EndsAt = endsAt,
            },
        };
    }
}
