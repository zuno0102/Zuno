using MediatR;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Caching.Memory;
using Microsoft.Extensions.Options;
using Zuno.Marketplace.Application.Common;
using Zuno.Marketplace.Domain.Entities;
using Zuno.Marketplace.Domain.Enums;

namespace Zuno.Marketplace.Application.Customer;

/// <summary>
/// The customer's Marketplace home: one section per active row of <c>ref_marketplace_home_sections</c>,
/// in order, each filled from its source and left out when it has nothing.
/// </summary>
/// <remarks>
/// Sections shared by every customer (newest, B2B, trending, discounts, "For men", best sellers,
/// most reviewed) are ranked once and the ranking cached for <see cref="MarketplaceSettings.HomeCacheSeconds"/>;
/// the cards themselves are always read fresh through the visibility rule, so a post that sold out
/// or was paused a second ago is not shown. Banners and food are the customer's districts', and
/// "Recommended" and "Wishlist" their own, so those are read each time.
/// </remarks>
public class MarketplaceHomeHandler(
    ICurrentUser currentUser,
    IMarketplaceDbContext dbContext,
    MarketplaceReference reference,
    TimeProvider clock,
    IOptions<MarketplaceSettings> settings,
    IMemoryCache cache) : IRequestHandler<GetMarketplaceHomeQuery, MarketplaceHomeDto>
{
    /// <summary>The product detail the audience sections read ("For": Men, Women, Kids, Unisex).</summary>
    public const string AudienceKey = "for";

    /// <summary>Orders that count as bought: placed and not cancelled (an unpaid online order is not yet bought).</summary>
    private static readonly MarketplaceOrderStatus[] Bought =
    [
        MarketplaceOrderStatus.Placed,
        MarketplaceOrderStatus.Confirmed,
        MarketplaceOrderStatus.Shipped,
        MarketplaceOrderStatus.OutForDelivery,
        MarketplaceOrderStatus.Delivered,
        MarketplaceOrderStatus.Closed,
    ];

    /// <summary>How many of the customer's latest orders and saves "Recommended" learns from.</summary>
    private const int TasteSampleSize = 50;

    public async Task<MarketplaceHomeDto> Handle(GetMarketplaceHomeQuery request, CancellationToken cancellationToken)
    {
        var userId = currentUser.OwnerId();
        var now = clock.GetUtcNow();
        var rows = (await reference.HomeSectionsAsync(cancellationToken)).Where(s => s.IsActive).ToList();
        var context = new HomeContext(request, userId, now, rows);

        var sections = new List<MarketplaceHomeSectionDto>();
        foreach (var row in rows)
        {
            var items = await ItemsAsync(row, context, cancellationToken);
            if (row.Source == MarketplaceHomeSource.Newest)
            {
                // The next "Newest" section carries on where this one stopped.
                context.NewestShown += row.ItemCount;
            }

            if (items.Count > 0 || row.Layout == MarketplaceHomeLayout.Feed)
            {
                sections.Add(new MarketplaceHomeSectionDto
                {
                    Code = row.Code,
                    Title = row.Title,
                    Layout = row.Layout.ToString(),
                    PageSize = row.ItemCount,
                    Items = items,
                });
            }
        }

        await dbContext.MarkFavouritesAsync(userId, [.. sections.SelectMany(s => s.Items)], cancellationToken);
        return new MarketplaceHomeDto { Sections = sections };
    }

    private sealed class HomeContext(GetMarketplaceHomeQuery request, Guid userId, DateTimeOffset now, List<MarketplaceHomeSection> rows)
    {
        public GetMarketplaceHomeQuery Request { get; } = request;

        public Guid UserId { get; } = userId;

        public DateTimeOffset Now { get; } = now;

        public List<MarketplaceHomeSection> Rows { get; } = rows;

        public int NewestShown { get; set; }
    }

    private IQueryable<MarketplacePost> Visible(DateTimeOffset now) =>
        dbContext.Posts.VisibleToCustomers(dbContext.Businesses, now);

    private IQueryable<MarketplacePost> Products(DateTimeOffset now) =>
        Visible(now).Where(MarketplaceQueries.IsProduct);

    private Task<List<MarketplaceCardDto>> ItemsAsync(MarketplaceHomeSection row, HomeContext context, CancellationToken cancellationToken)
    {
        var count = row.ItemCount;
        var now = context.Now;
        var shown = context.NewestShown;
        return row.Source switch
        {
            MarketplaceHomeSource.Newest => RankedAsync(
                $"{row.Code}:{shown}",
                count,
                Products(now),
                pool => Products(now).OrderByDescending(p => p.CreatedDate).ThenBy(p => p.Id).Skip(shown).Take(pool),
                cancellationToken),
            MarketplaceHomeSource.Wholesale => RankedAsync(
                row.Code,
                count,
                Visible(now).Where(p => p.TradeType == MarketplaceTradeType.Wholesale),
                pool => Visible(now).Where(p => p.TradeType == MarketplaceTradeType.Wholesale)
                    .OrderByDescending(p => p.CreatedDate).ThenBy(p => p.Id).Take(pool),
                cancellationToken),
            MarketplaceHomeSource.Trending => RankedByOrdersAsync(
                row.Code, count, now, o => o.CreatedDate >= now.AddDays(-settings.Value.TrendingDays), byUnits: false, cancellationToken),
            MarketplaceHomeSource.BestSellers => RankedByOrdersAsync(row.Code, count, now, _ => true, byUnits: true, cancellationToken),
            MarketplaceHomeSource.MostReviewed => RankedByOrdersAsync(
                row.Code, count, now, o => o.RatingScore != null, byUnits: false, cancellationToken),
            MarketplaceHomeSource.Discount => DiscountAsync(row, context, cancellationToken),
            MarketplaceHomeSource.Audience => AudienceAsync(row, now, cancellationToken),
            MarketplaceHomeSource.Banners => BannersAsync(count, context, cancellationToken),
            MarketplaceHomeSource.Food => FoodAsync(count, context, cancellationToken),
            MarketplaceHomeSource.Recommended => RecommendedAsync(count, context, cancellationToken),
            MarketplaceHomeSource.Wishlist => dbContext.CardsAsync(
                Visible(now)
                    .Where(p => dbContext.Favourites.Any(f => f.UserId == context.UserId && f.PostId == p.Id))
                    .OrderByDescending(p => dbContext.Favourites
                        .Where(f => f.UserId == context.UserId && f.PostId == p.Id)
                        .Select(f => f.CreatedDate)
                        .FirstOrDefault())
                    .Take(count),
                cancellationToken),

            // The feed is paged by the app through the home-feed search.
            _ => Task.FromResult(new List<MarketplaceCardDto>()),
        };
    }

    /// <summary>
    /// The first <paramref name="count"/> of a cached ranking that are on show now. The ranking keeps
    /// a few more than shown, so a post that just sold out leaves no gap.
    /// </summary>
    private async Task<List<MarketplaceCardDto>> RankedAsync(
        string key,
        int count,
        IQueryable<MarketplacePost> onShow,
        Func<int, IQueryable<MarketplacePost>> rank,
        CancellationToken cancellationToken)
    {
        var ids = await CachedIdsAsync(key, () => rank(count * 2).Select(p => p.Id).ToListAsync(cancellationToken));
        return await InRankOrderAsync(onShow, ids, count, cancellationToken);
    }

    /// <summary>Products ranked by their orders: how many units, or how many orders, matching <paramref name="counts"/>.</summary>
    private async Task<List<MarketplaceCardDto>> RankedByOrdersAsync(
        string key,
        int count,
        DateTimeOffset now,
        System.Linq.Expressions.Expression<Func<MarketplaceOrder, bool>> counts,
        bool byUnits,
        CancellationToken cancellationToken)
    {
        // Ranked from more than shown: some of the top sellers may be B2B lots, paused or sold out.
        var pool = count * 3;
        var ids = await CachedIdsAsync(key, async () =>
        {
            var orders = dbContext.Orders.AsNoTracking().Where(o => Bought.Contains(o.Status)).Where(counts).GroupBy(o => o.PostId);
            var ranked = byUnits
                ? orders.OrderByDescending(g => g.Sum(o => o.Quantity)).ThenBy(g => g.Key)
                : orders.OrderByDescending(g => g.Count()).ThenBy(g => g.Key);
            return await ranked.Select(g => g.Key).Take(pool).ToListAsync(cancellationToken);
        });
        return await InRankOrderAsync(Products(now), ids, count, cancellationToken);
    }

    /// <summary>
    /// Products at least the row's percentage below their MRP and under the next bigger band's, the
    /// biggest discount first: "Min 30% off" holds 30–49% when there is a 50% band.
    /// </summary>
    private Task<List<MarketplaceCardDto>> DiscountAsync(MarketplaceHomeSection row, HomeContext context, CancellationToken cancellationToken)
    {
        if (!int.TryParse(row.Parameter, out var least))
        {
            return Task.FromResult(new List<MarketplaceCardDto>());
        }

        var below = context.Rows
            .Where(r => r.Source == MarketplaceHomeSource.Discount)
            .Select(r => int.TryParse(r.Parameter, out var p) ? p : (int?)null)
            .Where(p => p > least)
            .Min();
        var now = context.Now;
        IQueryable<MarketplacePost> Discounted()
        {
            var posts = Products(now).Where(p => p.OriginalPrice != null && p.Price != null && p.OriginalPrice > p.Price)
                .Where(p => (p.OriginalPrice!.Value - p.Price!.Value) * 100 >= p.OriginalPrice.Value * least);
            return below is { } upTo
                ? posts.Where(p => (p.OriginalPrice!.Value - p.Price!.Value) * 100 < p.OriginalPrice.Value * upTo)
                : posts;
        }

        return RankedAsync(
            row.Code,
            row.ItemCount,
            Discounted(),
            pool => Discounted()
                .OrderByDescending(p => (p.OriginalPrice!.Value - p.Price!.Value) / p.OriginalPrice.Value)
                .ThenBy(p => p.Id)
                .Take(pool),
            cancellationToken);
    }

    /// <summary>Products whose "For" detail is one of the row's values, newest first.</summary>
    private Task<List<MarketplaceCardDto>> AudienceAsync(MarketplaceHomeSection row, DateTimeOffset now, CancellationToken cancellationToken)
    {
        var values = (row.Parameter ?? string.Empty)
            .Split(',', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries)
            .ToList();
        if (values.Count == 0)
        {
            return Task.FromResult(new List<MarketplaceCardDto>());
        }

        IQueryable<MarketplacePost> ForThem() =>
            Products(now).Where(p => p.Attributes.Any(a => a.Key == AudienceKey && values.Contains(a.Value)));
        return RankedAsync(
            row.Code,
            row.ItemCount,
            ForThem(),
            pool => ForThem().OrderByDescending(p => p.CreatedDate).ThenBy(p => p.Id).Take(pool),
            cancellationToken);
    }

    /// <summary>
    /// Adverts with a paid banner running and their banner photo, in the customer's districts, newest
    /// first. A banner is sold, never given: none paid, no banner section.
    /// </summary>
    private Task<List<MarketplaceCardDto>> BannersAsync(int count, HomeContext context, CancellationToken cancellationToken) =>
        dbContext.CardsAsync(
            Visible(context.Now)
                .Where(p => p.Kind == MarketplacePostKind.Advertisement && p.Media.Any(m => m.VariantId == null))
                .Where(p => p.BannerPaidUntil != null && p.BannerPaidUntil > context.Now)
                .InDistricts(context.Request.DistrictIds)
                .OrderByDescending(p => p.CreatedDate)
                .Take(count),
            cancellationToken);

    /// <summary>Food ending soonest; with the customer's place, the nearest of the soonest few.</summary>
    private async Task<List<MarketplaceCardDto>> FoodAsync(int count, HomeContext context, CancellationToken cancellationToken)
    {
        var request = context.Request;
        var pool = Visible(context.Now)
            .Where(p => p.Kind == MarketplacePostKind.FoodOffer)
            .InDistricts(request.DistrictIds)
            .OrderBy(p => p.EndsAt)
            .ThenBy(p => p.Id);
        var food = await dbContext.CardsAsync(
            request.Latitude is null ? pool.Take(count) : pool.Take(settings.Value.HomeNearbyPoolSize),
            cancellationToken);
        food.MeasureFrom(request.Latitude, request.Longitude);
        return request.Latitude is null
            ? food
            : [.. food.OrderBy(c => c.DistanceKm ?? double.MaxValue).Take(count)];
    }

    /// <summary>
    /// Newest products in the kinds of thing (sub-categories) the customer last ordered or saved,
    /// leaving out what they already ordered.
    /// </summary>
    private async Task<List<MarketplaceCardDto>> RecommendedAsync(int count, HomeContext context, CancellationToken cancellationToken)
    {
        var userId = context.UserId;
        var ordered = await dbContext.Orders.AsNoTracking()
            .Where(o => o.CustomerUserId == userId)
            .OrderByDescending(o => o.CreatedDate)
            .Take(TasteSampleSize)
            .Select(o => new { o.PostId, o.Post.SubCategoryId })
            .ToListAsync(cancellationToken);
        var saved = await dbContext.Favourites.AsNoTracking()
            .Where(f => f.UserId == userId)
            .OrderByDescending(f => f.CreatedDate)
            .Take(TasteSampleSize)
            .Select(f => f.Post.SubCategoryId)
            .ToListAsync(cancellationToken);

        var kinds = ordered.Select(o => o.SubCategoryId).Concat(saved).OfType<Guid>().Distinct().ToList();
        if (kinds.Count == 0)
        {
            return [];
        }

        var bought = ordered.Select(o => o.PostId).Distinct().ToList();
        return await dbContext.CardsAsync(
            Products(context.Now)
                .Where(p => p.SubCategoryId != null && kinds.Contains(p.SubCategoryId.Value))
                .Where(p => !bought.Contains(p.Id))
                .Where(p => p.OwnerUserId != userId)
                .OrderByDescending(p => p.CreatedDate)
                .ThenBy(p => p.Id)
                .Take(count),
            cancellationToken);
    }

    private async Task<List<Guid>> CachedIdsAsync(string key, Func<Task<List<Guid>>> load)
    {
        var seconds = settings.Value.HomeCacheSeconds;
        if (seconds <= 0)
        {
            return await load();
        }

        var cacheKey = $"marketplace:home:{key}";
        if (cache.TryGetValue(cacheKey, out List<Guid>? ids) && ids is not null)
        {
            return ids;
        }

        ids = await load();
        cache.Set(cacheKey, ids, TimeSpan.FromSeconds(seconds));
        return ids;
    }

    /// <summary>The cards of <paramref name="ids"/> still in <paramref name="onShow"/>, in the ids' order, at most <paramref name="count"/>.</summary>
    private async Task<List<MarketplaceCardDto>> InRankOrderAsync(
        IQueryable<MarketplacePost> onShow, List<Guid> ids, int count, CancellationToken cancellationToken)
    {
        if (ids.Count == 0)
        {
            return [];
        }

        var cards = await dbContext.CardsAsync(onShow.Where(p => ids.Contains(p.Id)), cancellationToken);
        var rank = ids.Select((id, i) => (id, i)).ToDictionary(x => x.id, x => x.i);
        return [.. cards.OrderBy(c => rank[c.Id]).Take(count)];
    }
}
