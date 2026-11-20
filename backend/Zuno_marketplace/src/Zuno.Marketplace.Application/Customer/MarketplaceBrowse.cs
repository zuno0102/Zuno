using FluentValidation;
using MediatR;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Options;
using Zuno.Marketplace.Application.Common;
using Zuno.Marketplace.Domain.Entities;
using Zuno.Marketplace.Domain.Enums;
using Zuno.Marketplace.Domain.Exceptions;

namespace Zuno.Marketplace.Application.Customer;

/// <summary>A post on a customer's card: photo, price, where, who sells it, and whether it is saved.</summary>
public class MarketplaceCardDto
{
    public Guid Id { get; set; }

    /// <summary><c>Listing</c>, <c>FoodOffer</c> or <c>Advertisement</c>.</summary>
    public string Kind { get; set; } = string.Empty;

    public string Title { get; set; } = string.Empty;

    public Guid CategoryId { get; set; }

    public string CategoryName { get; set; } = string.Empty;

    public string? SubCategoryName { get; set; }

    public decimal? Price { get; set; }

    /// <summary>A food offer's usual price, shown struck through.</summary>
    public decimal? OriginalPrice { get; set; }

    public string? PriceUnit { get; set; }

    /// <summary><c>Retail</c> or <c>Wholesale</c> (a B2B lot).</summary>
    public string TradeType { get; set; } = string.Empty;

    public int? MinOrderQuantity { get; set; }

    /// <summary>Stock left, portions left, or the B2B lot's quantity; null when not stated.</summary>
    public int? Quantity { get; set; }

    /// <summary><c>New</c> or <c>Used</c>; null outside a category that keeps stock.</summary>
    public string? Condition { get; set; }

    public string? ImageUrl { get; set; }

    public string? Area { get; set; }

    public string DistrictName { get; set; } = string.Empty;

    public string BusinessName { get; set; } = string.Empty;

    public DateTimeOffset? StartsAt { get; set; }

    public DateTimeOffset? EndsAt { get; set; }

    public double? Latitude { get; set; }

    public double? Longitude { get; set; }

    /// <summary>From the customer's place, when they sent one and the post has a pin.</summary>
    public double? DistanceKm { get; set; }

    public bool IsFavourite { get; set; }

    /// <summary>False on a wishlist card whose post is no longer on show (sold, ended, switched off).</summary>
    public bool IsAvailable { get; set; } = true;
}

public class MarketplaceCardPageDto
{
    public List<MarketplaceCardDto> Items { get; set; } = [];

    public int Page { get; set; }

    public int PageSize { get; set; }

    public int TotalCount { get; set; }
}

/// <summary>The customer's Marketplace home: advert banners, food near them, products and B2B lots.</summary>
public class MarketplaceHomeDto
{
    public List<MarketplaceCardDto> Banners { get; set; } = [];

    public List<MarketplaceCardDto> Food { get; set; } = [];

    public List<MarketplaceCardDto> Products { get; set; } = [];

    public List<MarketplaceCardDto> Wholesale { get; set; } = [];
}

/// <summary>A post as a customer opens it.</summary>
public class MarketplacePostDetailDto
{
    public MarketplaceCardDto Card { get; set; } = new();

    public string? Description { get; set; }

    /// <summary>A product only: how many come in one item sold.</summary>
    public int? PackQuantity { get; set; }

    /// <summary>The category's details with their labels ("Fabric: Silk"), then the business's own.</summary>
    public List<MarketplaceCustomDetailDto> Details { get; set; } = [];

    /// <summary>The colours / sizes on sale: the main one first, then each switched on.</summary>
    public List<MarketplaceVariantDto> Variants { get; set; } = [];

    public List<MarketplacePostMediaDto> Media { get; set; } = [];

    /// <summary>The number to call about an advert or food offer.</summary>
    public string? ContactPhone { get; set; }

    public string? BusinessLogoUrl { get; set; }

    /// <summary>The ways this seller takes payment now, in order — online only while it can be taken.</summary>
    public List<MarketplaceOptionDto> PaymentMethods { get; set; } = [];

    /// <summary>A product with a stock count: ordered in the app.</summary>
    public bool CanOrder { get; set; }

    /// <summary>A B2B lot: asked for with a request.</summary>
    public bool CanRequest { get; set; }

    public bool DeliversEverywhere { get; set; }

    /// <summary>The state it ships in when not all over India.</summary>
    public string? DeliveryStateName { get; set; }

    /// <summary>The districts of that state it ships to; empty is the whole state.</summary>
    public List<string> DeliveryDistrictNames { get; set; } = [];
}

/// <summary>The home. Food and adverts are local: <see cref="DistrictIds"/> keeps them to the customer's districts.</summary>
public class GetMarketplaceHomeQuery : IRequest<MarketplaceHomeDto>
{
    public List<Guid> DistrictIds { get; set; } = [];

    /// <summary>The customer's place, both or neither: food is then sorted nearest first.</summary>
    public double? Latitude { get; set; }

    public double? Longitude { get; set; }
}

/// <summary>Posts by kind, category, words and district, a page at a time, newest first (food: ending soonest).</summary>
public class SearchMarketplacePostsQuery : IRequest<MarketplaceCardPageDto>
{
    /// <summary><c>Listing</c>, <c>FoodOffer</c> or <c>Advertisement</c>; null for all.</summary>
    public string? Kind { get; set; }

    /// <summary>True: B2B lots only; false: no B2B lots; null: both.</summary>
    public bool? Wholesale { get; set; }

    public Guid? CategoryId { get; set; }

    public Guid? SubCategoryId { get; set; }

    public string? Keyword { get; set; }

    public List<Guid> DistrictIds { get; set; } = [];

    public double? Latitude { get; set; }

    public double? Longitude { get; set; }

    public int Page { get; set; } = 1;

    public int? PageSize { get; set; }
}

public class GetMarketplacePostDetailQuery : IRequest<MarketplacePostDetailDto>
{
    public Guid Id { get; set; }
}

public class GetMyFavouritesQuery : IRequest<MarketplaceCardPageDto>
{
    public int Page { get; set; } = 1;

    public int? PageSize { get; set; }
}

/// <summary>Saves a post to the wishlist. Saving one already there changes nothing.</summary>
public class AddFavouriteCommand : IRequest<Unit>
{
    public Guid PostId { get; set; }
}

/// <summary>Takes a post off the wishlist. Taking one not there changes nothing.</summary>
public class RemoveFavouriteCommand : IRequest<Unit>
{
    public Guid PostId { get; set; }
}

internal static class PlaceRules
{
    /// <summary>A place is both coordinates in range, or neither.</summary>
    public static bool IsPlace(double? latitude, double? longitude) =>
        (latitude is null && longitude is null)
        || (latitude is >= -90 and <= 90 && longitude is >= -180 and <= 180);
}

public class GetMarketplaceHomeQueryValidator : AbstractValidator<GetMarketplaceHomeQuery>
{
    public GetMarketplaceHomeQueryValidator()
    {
        RuleFor(x => x.DistrictIds.Count).LessThanOrEqualTo(20).WithMessage("Choose up to 20 districts.");
        RuleFor(x => x).Must(x => PlaceRules.IsPlace(x.Latitude, x.Longitude)).WithMessage("Send both latitude and longitude, or neither.");
    }
}

public class SearchMarketplacePostsQueryValidator : AbstractValidator<SearchMarketplacePostsQuery>
{
    public SearchMarketplacePostsQueryValidator(IOptions<MarketplaceSettings> settings)
    {
        RuleFor(x => x.Kind)
            .Must(k => k is null || Enum.TryParse<MarketplacePostKind>(k, true, out var v) && Enum.IsDefined(v))
            .WithMessage("Unknown post kind.");
        RuleFor(x => x.Keyword).MaximumLength(settings.Value.MaxSearchLength);
        RuleFor(x => x.DistrictIds.Count).LessThanOrEqualTo(20).WithMessage("Choose up to 20 districts.");
        RuleFor(x => x).Must(x => PlaceRules.IsPlace(x.Latitude, x.Longitude)).WithMessage("Send both latitude and longitude, or neither.");
    }
}

public class AddFavouriteCommandValidator : AbstractValidator<AddFavouriteCommand>
{
    public AddFavouriteCommandValidator() => RuleFor(x => x.PostId).NotEmpty();
}

/// <summary>Cards for customers: one projection, every column a card needs, and the saved hearts in one more read.</summary>
internal static class MarketplaceCards
{
    public static IQueryable<MarketplacePost> InDistricts(this IQueryable<MarketplacePost> posts, List<Guid> districtIds) =>
        districtIds.Count == 0 ? posts : posts.Where(p => districtIds.Contains(p.DistrictId));

    /// <summary>The cards of <paramref name="posts"/>, in the query's order.</summary>
    public static async Task<List<MarketplaceCardDto>> CardsAsync(
        this IMarketplaceDbContext dbContext, IQueryable<MarketplacePost> posts, CancellationToken cancellationToken) =>
        await posts
            .AsNoTracking()
            .Select(p => new MarketplaceCardDto
            {
                Id = p.Id,
                Kind = p.Kind.ToString(),
                Title = p.Title,
                CategoryId = p.CategoryId,
                CategoryName = p.Category.Name,
                SubCategoryName = p.SubCategory == null ? null : p.SubCategory.Name,
                Price = p.Price,
                OriginalPrice = p.OriginalPrice,
                PriceUnit = p.PriceUnit,
                TradeType = p.TradeType.ToString(),
                MinOrderQuantity = p.MinOrderQuantity,
                Quantity = p.Quantity,
                Condition = p.Condition == null ? null : p.Condition.ToString(),
                ImageUrl = p.Media
                    .Where(m => m.VariantId == null)
                    .OrderBy(m => m.SortOrder)
                    .Select(m => m.Url)
                    .FirstOrDefault(),
                Area = p.Area,
                DistrictName = p.District.Name,
                BusinessName = dbContext.Businesses
                    .Where(b => b.OwnerUserId == p.OwnerUserId)
                    .Select(b => b.Name)
                    .FirstOrDefault() ?? string.Empty,
                StartsAt = p.StartsAt,
                EndsAt = p.EndsAt,
                Latitude = p.Latitude,
                Longitude = p.Longitude,
            })
            .ToListAsync(cancellationToken);

    /// <summary>Fills the hearts of every card the customer saved, in one read.</summary>
    public static async Task MarkFavouritesAsync(
        this IMarketplaceDbContext dbContext, Guid userId, IReadOnlyCollection<MarketplaceCardDto> cards, CancellationToken cancellationToken)
    {
        if (cards.Count == 0)
        {
            return;
        }

        var ids = cards.Select(c => c.Id).Distinct().ToList();
        var saved = (await dbContext.Favourites.AsNoTracking()
                .Where(f => f.UserId == userId && ids.Contains(f.PostId))
                .Select(f => f.PostId)
                .ToListAsync(cancellationToken))
            .ToHashSet();
        foreach (var card in cards)
        {
            card.IsFavourite = saved.Contains(card.Id);
        }
    }

    /// <summary>Sets each card's distance from the customer's place, when both have one.</summary>
    public static void MeasureFrom(this IEnumerable<MarketplaceCardDto> cards, double? latitude, double? longitude)
    {
        if (latitude is not { } lat || longitude is not { } lng)
        {
            return;
        }

        foreach (var card in cards)
        {
            if (card.Latitude is { } toLat && card.Longitude is { } toLng)
            {
                card.DistanceKm = Math.Round(GeoDistance.HaversineKm(lat, lng, toLat, toLng), 1);
            }
        }
    }
}

public class MarketplaceBrowseHandlers(
    ICurrentUser currentUser,
    IMarketplaceDbContext dbContext,
    MarketplaceReference reference,
    IMarketplacePaymentGateway gateway,
    TimeProvider clock,
    IOptions<MarketplaceSettings> settings) :
    IRequestHandler<GetMarketplaceHomeQuery, MarketplaceHomeDto>,
    IRequestHandler<SearchMarketplacePostsQuery, MarketplaceCardPageDto>,
    IRequestHandler<GetMarketplacePostDetailQuery, MarketplacePostDetailDto>,
    IRequestHandler<GetMyFavouritesQuery, MarketplaceCardPageDto>,
    IRequestHandler<AddFavouriteCommand, Unit>,
    IRequestHandler<RemoveFavouriteCommand, Unit>
{
    private IQueryable<MarketplacePost> Visible(DateTimeOffset now) =>
        dbContext.Posts.VisibleToCustomers(dbContext.Businesses, now);

    public async Task<MarketplaceHomeDto> Handle(GetMarketplaceHomeQuery request, CancellationToken cancellationToken)
    {
        var userId = currentUser.OwnerId();
        var now = clock.GetUtcNow();
        var size = settings.Value.HomeSectionSize;
        var visible = Visible(now);

        // Adverts with their banner photo, newest first.
        var banners = await dbContext.CardsAsync(
            visible.Where(p => p.Kind == MarketplacePostKind.Advertisement && p.Media.Any(m => m.VariantId == null))
                .InDistricts(request.DistrictIds)
                .OrderByDescending(p => p.CreatedDate)
                .Take(settings.Value.HomeBannerCount),
            cancellationToken);

        // Food ending soonest; with the customer's place, the nearest of the soonest few.
        var foodPool = visible.Where(p => p.Kind == MarketplacePostKind.FoodOffer)
            .InDistricts(request.DistrictIds)
            .OrderBy(p => p.EndsAt)
            .ThenBy(p => p.Id);
        var food = await dbContext.CardsAsync(
            request.Latitude is null ? foodPool.Take(size) : foodPool.Take(settings.Value.HomeNearbyPoolSize),
            cancellationToken);
        food.MeasureFrom(request.Latitude, request.Longitude);
        if (request.Latitude is not null)
        {
            food = food.OrderBy(c => c.DistanceKm ?? double.MaxValue).Take(size).ToList();
        }

        // Products and B2B lots ship or are traded across districts: newest first, everywhere.
        var products = await dbContext.CardsAsync(
            visible.Where(MarketplaceQueries.IsProduct).OrderByDescending(p => p.CreatedDate).Take(size),
            cancellationToken);
        var wholesale = await dbContext.CardsAsync(
            visible.Where(p => p.TradeType == MarketplaceTradeType.Wholesale).OrderByDescending(p => p.CreatedDate).Take(size),
            cancellationToken);

        await dbContext.MarkFavouritesAsync(userId, [.. banners, .. food, .. products, .. wholesale], cancellationToken);
        return new MarketplaceHomeDto { Banners = banners, Food = food, Products = products, Wholesale = wholesale };
    }

    public async Task<MarketplaceCardPageDto> Handle(SearchMarketplacePostsQuery request, CancellationToken cancellationToken)
    {
        var userId = currentUser.OwnerId();
        var (page, pageSize) = MarketplaceQueries.Paging(request.Page, request.PageSize, settings.Value);
        var posts = Visible(clock.GetUtcNow()).InDistricts(request.DistrictIds);

        var hasKind = Enum.TryParse<MarketplacePostKind>(request.Kind, true, out var kind);
        if (hasKind)
        {
            posts = posts.Where(p => p.Kind == kind);
        }

        if (request.Wholesale is { } wholesale)
        {
            posts = wholesale
                ? posts.Where(p => p.TradeType == MarketplaceTradeType.Wholesale)
                : posts.Where(p => p.TradeType != MarketplaceTradeType.Wholesale);
        }

        if (request.CategoryId is { } categoryId)
        {
            posts = posts.Where(p => p.CategoryId == categoryId);
        }

        if (request.SubCategoryId is { } subCategoryId)
        {
            posts = posts.Where(p => p.SubCategoryId == subCategoryId);
        }

        if (!string.IsNullOrWhiteSpace(request.Keyword))
        {
            // Case-insensitive words in the title, the category or the sub-category. LIKE's own
            // wildcards in the words are taken literally.
            var pattern = $"%{EscapeLike(request.Keyword.Trim().ToLowerInvariant())}%";
            posts = posts.Where(p =>
                EF.Functions.Like(p.Title.ToLower(), pattern, "\\")
                || EF.Functions.Like(p.Category.Name.ToLower(), pattern, "\\")
                || (p.SubCategory != null && EF.Functions.Like(p.SubCategory.Name.ToLower(), pattern, "\\")));
        }

        var total = await posts.CountAsync(cancellationToken);
        var ordered = hasKind && kind == MarketplacePostKind.FoodOffer
            ? posts.OrderBy(p => p.EndsAt).ThenBy(p => p.Id)
            : posts.OrderByDescending(p => p.CreatedDate).ThenBy(p => p.Id);
        var cards = total == 0
            ? []
            : await dbContext.CardsAsync(ordered.Skip((page - 1) * pageSize).Take(pageSize), cancellationToken);
        cards.MeasureFrom(request.Latitude, request.Longitude);
        await dbContext.MarkFavouritesAsync(userId, cards, cancellationToken);

        return new MarketplaceCardPageDto { Items = cards, Page = page, PageSize = pageSize, TotalCount = total };
    }

    public async Task<MarketplacePostDetailDto> Handle(GetMarketplacePostDetailQuery request, CancellationToken cancellationToken)
    {
        var userId = currentUser.OwnerId();
        var now = clock.GetUtcNow();

        // Hidden posts are simply not found: a paused, sold-out or unverified post does not exist to customers.
        var post = await Visible(now).AsNoTracking().WithCard()
            .FirstOrDefaultAsync(p => p.Id == request.Id, cancellationToken)
            ?? throw new EntityNotFoundException("Post", request.Id);

        var card = (await dbContext.CardsAsync(dbContext.Posts.Where(p => p.Id == post.Id), cancellationToken)).Single();
        await dbContext.MarkFavouritesAsync(userId, [card], cancellationToken);
        var business = await dbContext.Businesses.AsNoTracking().FirstAsync(b => b.OwnerUserId == post.OwnerUserId, cancellationToken);

        // The same mapping the business screens use, then only what is on sale.
        var shown = post.ToDto(now, []);
        var main = post.MainVariant;
        var onSale = post.Variants.Where(v => v == main || v.IsActive).Select(v => v.Id).ToHashSet();

        return new MarketplacePostDetailDto
        {
            Card = card,
            Description = post.Description,
            PackQuantity = post.PackQuantity,
            Details = await DetailsAsync(post, cancellationToken),
            Variants = shown.Variants.Where(v => onSale.Contains(v.Id)).ToList(),
            Media = shown.Media,
            ContactPhone = post.ContactPhone,
            BusinessLogoUrl = business.LogoUrl,
            PaymentMethods = await PaymentMethodsAsync(business, cancellationToken),
            CanOrder = post.KeepsStock && !post.IsWholesale,
            CanRequest = post.IsWholesale,
            DeliversEverywhere = post.DeliversEverywhere,
            DeliveryStateName = post.DeliversEverywhere || post.DeliveryStateId is null
                ? null
                : await dbContext.States.Where(s => s.Id == post.DeliveryStateId).Select(s => s.Name).FirstOrDefaultAsync(cancellationToken),
            DeliveryDistrictNames = post.DeliversEverywhere || post.DeliveryDistrictIds.Count == 0
                ? []
                : await dbContext.Districts.Where(d => post.DeliveryDistrictIds.Contains(d.Id)).OrderBy(d => d.Name).Select(d => d.Name).ToListAsync(cancellationToken),
        };
    }

    public async Task<MarketplaceCardPageDto> Handle(GetMyFavouritesQuery request, CancellationToken cancellationToken)
    {
        var userId = currentUser.OwnerId();
        var (page, pageSize) = MarketplaceQueries.Paging(request.Page, request.PageSize, settings.Value);

        // A deleted post leaves the list; one no longer on show stays, marked, so it can be taken off.
        var mine = dbContext.Favourites.AsNoTracking()
            .Where(f => f.UserId == userId && dbContext.Posts.Any(p => p.Id == f.PostId));
        var total = await mine.CountAsync(cancellationToken);
        if (total == 0)
        {
            return new MarketplaceCardPageDto { Page = page, PageSize = pageSize };
        }

        var ids = await mine.OrderByDescending(f => f.CreatedDate).ThenBy(f => f.PostId)
            .Skip((page - 1) * pageSize).Take(pageSize)
            .Select(f => f.PostId)
            .ToListAsync(cancellationToken);
        var cards = (await dbContext.CardsAsync(dbContext.Posts.Where(p => ids.Contains(p.Id)), cancellationToken)).ToDictionary(c => c.Id);
        var available = (await Visible(clock.GetUtcNow()).Where(p => ids.Contains(p.Id)).Select(p => p.Id).ToListAsync(cancellationToken)).ToHashSet();

        var items = ids.Where(cards.ContainsKey).Select(id => cards[id]).ToList();
        foreach (var card in items)
        {
            card.IsFavourite = true;
            card.IsAvailable = available.Contains(card.Id);
        }

        return new MarketplaceCardPageDto { Items = items, Page = page, PageSize = pageSize, TotalCount = total };
    }

    public async Task<Unit> Handle(AddFavouriteCommand request, CancellationToken cancellationToken)
    {
        var userId = currentUser.OwnerId();
        if (await dbContext.Favourites.AnyAsync(f => f.UserId == userId && f.PostId == request.PostId, cancellationToken))
        {
            return Unit.Value;
        }

        if (!await Visible(clock.GetUtcNow()).AnyAsync(p => p.Id == request.PostId, cancellationToken))
        {
            throw new EntityNotFoundException("Post", request.PostId);
        }

        var limit = settings.Value.MaxFavourites;
        if (await dbContext.Favourites.CountAsync(f => f.UserId == userId, cancellationToken) >= limit)
        {
            throw new DomainException($"Your wishlist is full ({limit} items). Remove some to save more.");
        }

        dbContext.Favourites.Add(new MarketplaceFavourite { UserId = userId, PostId = request.PostId, CreatedDate = clock.GetUtcNow() });
        try
        {
            await dbContext.SaveChangesAsync(cancellationToken);
        }
        catch (DbUpdateException)
        {
            // A second tap may have saved it a moment earlier: then it is saved, which is what was
            // asked. Anything else is a real failure.
            if (!await dbContext.Favourites.AsNoTracking().AnyAsync(f => f.UserId == userId && f.PostId == request.PostId, cancellationToken))
            {
                throw;
            }
        }

        return Unit.Value;
    }

    public async Task<Unit> Handle(RemoveFavouriteCommand request, CancellationToken cancellationToken)
    {
        var userId = currentUser.OwnerId();
        var row = await dbContext.Favourites.FirstOrDefaultAsync(f => f.UserId == userId && f.PostId == request.PostId, cancellationToken);
        if (row is not null)
        {
            dbContext.Favourites.Remove(row);
            await dbContext.SaveChangesAsync(cancellationToken);
        }

        return Unit.Value;
    }

    /// <summary>The category's details under their labels (with the unit), in the form's order, then the business's own.</summary>
    private async Task<List<MarketplaceCustomDetailDto>> DetailsAsync(MarketplacePost post, CancellationToken cancellationToken)
    {
        var category = (await reference.CategoriesAsync(cancellationToken)).FirstOrDefault(c => c.Id == post.CategoryId);
        // The fields this post was filled against: the whole category's and its own sub-category's.
        var fields = category?.Fields
            .Where(f => !f.IsDeleted && f.IsActive && (f.SubCategoryId is null || f.SubCategoryId == post.SubCategoryId))
            .ToList() ?? [];
        var values = post.Attributes
            .Where(a => !string.IsNullOrWhiteSpace(a.Value))
            .GroupBy(a => a.Key)
            .ToDictionary(g => g.Key, g => g.First().Value);

        return fields
            .Where(f => values.ContainsKey(f.Key))
            .DistinctBy(f => f.Key)
            .OrderBy(f => f.SubCategoryId is null ? 0 : 1)
            .ThenBy(f => f.DisplayOrder)
            .Select(f => new MarketplaceCustomDetailDto
            {
                Name = f.Label,
                Value = string.IsNullOrWhiteSpace(f.Unit) ? values[f.Key] : $"{values[f.Key]} {f.Unit}",
            })
            .Concat(post.CustomDetails.Select(d => new MarketplaceCustomDetailDto { Name = d.Key, Value = d.Value }))
            .ToList();
    }

    /// <summary>What the seller takes now: online only while the gateway can take it, so the app never offers a dead option.</summary>
    private async Task<List<MarketplaceOptionDto>> PaymentMethodsAsync(MarketplaceBusiness business, CancellationToken cancellationToken) =>
        (await reference.PaymentMethodsAsync(cancellationToken))
            .Where(m => m.Code switch
            {
                MarketplacePaymentMethod.CashOnDelivery => business.AcceptsCashOnDelivery,
                MarketplacePaymentMethod.Online => business.AcceptsOnlinePay && gateway.IsReady,
                _ => false,
            })
            .Select(m => new MarketplaceOptionDto { Code = m.Code.ToString(), Name = m.Name, Detail = m.Detail })
            .ToList();

    private static string EscapeLike(string text) =>
        text.Replace("\\", "\\\\", StringComparison.Ordinal)
            .Replace("%", "\\%", StringComparison.Ordinal)
            .Replace("_", "\\_", StringComparison.Ordinal);
}
