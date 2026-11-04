using MediatR;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Options;
using Zuno.Rent.Application.Common;
using Zuno.Rent.Domain.Entities;
using Zuno.Rent.Domain.Enums;
using Zuno.Rent.Domain.Exceptions;

namespace Zuno.Rent.Application.Customer;

/// <summary>A rent item on a customer card — photo, name, rate, where, and who rents it out.</summary>
public class RentalCardDto
{
    public Guid Id { get; set; }

    public string Name { get; set; } = string.Empty;

    public string CategoryName { get; set; } = string.Empty;

    public string PriceType { get; set; } = string.Empty;

    public decimal Price { get; set; }

    /// <summary>"/day", from the rate-type table.</summary>
    public string UnitSuffix { get; set; } = string.Empty;

    public string? ImageUrl { get; set; }

    /// <summary>One district it is offered in — one the customer picked, when there is a match.</summary>
    public string? DistrictName { get; set; }

    public string BusinessName { get; set; } = string.Empty;
}

/// <summary>One section of the Rent home, laid out as the section table says.</summary>
public class RentalHomeSectionDto
{
    public string Code { get; set; } = string.Empty;

    public string Title { get; set; } = string.Empty;

    /// <summary><c>Strip</c> (sideways) or <c>Grid</c> (two columns).</summary>
    public string Layout { get; set; } = string.Empty;

    public List<RentalCardDto> Items { get; set; } = [];
}

/// <summary>A rent item as a customer opens it.</summary>
public class RentalItemDetailDto
{
    public RentalCardDto Card { get; set; } = new();

    public string? Description { get; set; }

    public string? SubCategoryName { get; set; }

    /// <summary>"Per day", from the rate-type table.</summary>
    public string PriceTypeName { get; set; } = string.Empty;

    public int QuantityOwned { get; set; }

    /// <summary><c>None</c>, <c>PerOrder</c> or <c>PerPiece</c> — the booking sheet works out the advance from it.</summary>
    public string AdvanceType { get; set; } = string.Empty;

    public decimal? AdvanceAmount { get; set; }

    public List<RentalItemMediaDto> Media { get; set; } = [];

    public List<RentalItemDistrictDto> Districts { get; set; } = [];

    /// <summary>What the business asks before renting it out, in order.</summary>
    public List<RentalItemQuestionDto> Questions { get; set; } = [];

    /// <summary>What cancelling costs by time left, shown before booking. Empty is free cancellation.</summary>
    public List<RentalCancelStepDto> CancelSteps { get; set; } = [];

    /// <summary><c>Day</c> or <c>Hour</c>.</summary>
    public string CancelUnit { get; set; } = string.Empty;

    /// <summary><c>ByTimeLeft</c> (the steps) or <c>PerRentalDay</c>.</summary>
    public string CancelChargeType { get; set; } = string.Empty;

    /// <summary>For <c>PerRentalDay</c>: the percent for each day (or hour) rented.</summary>
    public decimal? CancelPercentPerDay { get; set; }

    /// <summary>The most the charge can add up to for this kind of item.</summary>
    public decimal MaxCancelPercent { get; set; }

    public string? BusinessLogoUrl { get; set; }
}

/// <summary>The customer's Rent home: sections from the section table, filled in a shuffle that <see cref="Seed"/> fixes.</summary>
public class GetRentalHomeQuery : IRequest<List<RentalHomeSectionDto>>
{
    /// <summary>A new seed is a new shuffle: the app sends a fresh one on every pull to refresh.</summary>
    public int Seed { get; set; }

    public List<Guid> DistrictIds { get; set; } = [];
}

/// <summary>Rent items by category, words and district.</summary>
public class SearchRentalsQuery : IRequest<List<RentalCardDto>>
{
    public Guid? CategoryId { get; set; }

    public string? Keyword { get; set; }

    public List<Guid> DistrictIds { get; set; } = [];
}

/// <summary>A few featured items with photos, changing daily.</summary>
public class GetRentalBannersQuery : IRequest<List<RentalCardDto>>
{
    public List<Guid> DistrictIds { get; set; } = [];
}

public class GetRentalItemDetailQuery : IRequest<RentalItemDetailDto>
{
    public Guid Id { get; set; }
}

/// <summary>How many a booking for these dates can take, as the customer sees it.</summary>
public class GetCustomerRentalAvailabilityQuery : IRequest<RentalAvailabilityDto>
{
    public Guid RentalItemId { get; set; }

    public DateTimeOffset StartDate { get; set; }

    public DateTimeOffset EndDate { get; set; }
}

/// <summary>What customers may see, the one rule everywhere they browse.</summary>
internal static class RentalVisibility
{
    /// <summary>Switched on, in an active category, and rented out by a verified business — as Service search shows only verified businesses.</summary>
    public static IQueryable<RentalItem> VisibleToCustomers(this IRentDbContext dbContext) =>
        dbContext.RentalItems.Where(i =>
            i.IsAvailable
            && i.RentalCategory.IsActive
            && dbContext.RentalBusinesses.Any(b => b.OwnerUserId == i.OwnerUserId && b.IsVerified));

    public static IQueryable<RentalItem> InDistricts(this IQueryable<RentalItem> items, List<Guid> districtIds) =>
        districtIds.Count == 0 ? items : items.Where(i => i.Districts.Any(d => districtIds.Contains(d.DistrictId)));

    /// <summary>Cards for [items], in the order the query gives — one query, every column a card needs.</summary>
    public static async Task<List<RentalCardDto>> CardsAsync(
        this IRentDbContext dbContext, IQueryable<RentalItem> items, List<Guid> districtIds, CancellationToken cancellationToken)
    {
        var suffixes = await dbContext.RentalPriceTypes.AsNoTracking().ToDictionaryAsync(p => p.Code, p => p.UnitSuffix, cancellationToken);

        var rows = await items
            .AsNoTracking()
            .Select(i => new
            {
                i.Id,
                i.Name,
                Category = i.RentalCategory.Name,
                i.PriceType,
                i.Price,
                Image = i.Media
                    .Where(m => m.MediaType == RentalMediaType.Image)
                    .OrderBy(m => m.SortOrder)
                    .Select(m => m.Url)
                    .FirstOrDefault(),
                District = i.Districts
                    .OrderBy(d => districtIds.Contains(d.DistrictId) ? 0 : 1)
                    .ThenBy(d => d.District.Name)
                    .Select(d => d.District.Name)
                    .FirstOrDefault(),
                Business = dbContext.RentalBusinesses
                    .Where(b => b.OwnerUserId == i.OwnerUserId)
                    .Select(b => b.Name)
                    .FirstOrDefault(),
            })
            .ToListAsync(cancellationToken);

        return rows.Select(r => new RentalCardDto
        {
            Id = r.Id,
            Name = r.Name,
            CategoryName = r.Category,
            PriceType = r.PriceType.ToString(),
            Price = r.Price,
            UnitSuffix = suffixes.GetValueOrDefault(r.PriceType) ?? string.Empty,
            ImageUrl = r.Image,
            DistrictName = r.District,
            BusinessName = r.Business ?? string.Empty,
        }).ToList();
    }
}

public class RentalBrowseHandlers(IRentDbContext dbContext, IOptions<RentSettings> settings, TimeProvider clock) :
    IRequestHandler<GetRentalHomeQuery, List<RentalHomeSectionDto>>,
    IRequestHandler<SearchRentalsQuery, List<RentalCardDto>>,
    IRequestHandler<GetRentalBannersQuery, List<RentalCardDto>>,
    IRequestHandler<GetRentalItemDetailQuery, RentalItemDetailDto>,
    IRequestHandler<GetCustomerRentalAvailabilityQuery, RentalAvailabilityDto>
{
    public async Task<List<RentalHomeSectionDto>> Handle(GetRentalHomeQuery request, CancellationToken cancellationToken)
    {
        var sections = await dbContext.RentalHomeSections
            .AsNoTracking()
            .Where(s => s.IsActive)
            .OrderBy(s => s.DisplayOrder)
            .ToListAsync(cancellationToken);

        // A bounded pool, newest first, with how often each has been rented — then shuffled in memory
        // by the seed, so the same seed gives the same home and a new one a different home.
        var pool = await dbContext.VisibleToCustomers()
            .InDistricts(request.DistrictIds)
            .OrderByDescending(i => i.CreatedDate)
            .Take(settings.Value.HomePoolSize)
            .Select(i => new { i.Id, Rented = dbContext.RentalOrders.Count(o => o.RentalItemId == i.Id) })
            .ToListAsync(cancellationToken);
        if (pool.Count == 0)
        {
            return [];
        }

        var random = new Random(request.Seed);
        var shuffled = pool.OrderBy(_ => random.Next()).ToList();
        var used = new HashSet<Guid>();
        var picks = new List<(RentalHomeSection Section, List<Guid> Ids)>();

        foreach (var section in sections)
        {
            // Unused items first; a small pool lets later sections repeat rather than stand empty.
            var candidates = shuffled.Where(p => !used.Contains(p.Id)).ToList();
            if (candidates.Count == 0)
            {
                candidates = shuffled;
            }

            var chosen = (section.ByPopularity ? candidates.OrderByDescending(p => p.Rented).ToList() : candidates)
                .Take(section.Size)
                .Select(p => p.Id)
                .ToList();
            chosen.ForEach(id => used.Add(id));
            picks.Add((section, chosen));
        }

        // One card query for every item on the page.
        var allIds = picks.SelectMany(p => p.Ids).Distinct().ToList();
        var cards = (await dbContext.CardsAsync(
                dbContext.RentalItems.Where(i => allIds.Contains(i.Id)), request.DistrictIds, cancellationToken))
            .ToDictionary(c => c.Id);

        return picks
            .Select(p => new RentalHomeSectionDto
            {
                Code = p.Section.Code,
                Title = p.Section.Title,
                Layout = p.Section.Layout.ToString(),
                Items = p.Ids.Where(cards.ContainsKey).Select(id => cards[id]).ToList(),
            })
            .Where(s => s.Items.Count > 0)
            .ToList();
    }

    public async Task<List<RentalCardDto>> Handle(SearchRentalsQuery request, CancellationToken cancellationToken)
    {
        var items = dbContext.VisibleToCustomers().InDistricts(request.DistrictIds);

        if (request.CategoryId is { } categoryId)
        {
            items = items.Where(i => i.RentalCategoryId == categoryId);
        }

        if (!string.IsNullOrWhiteSpace(request.Keyword))
        {
            // Case-insensitive words in the item, its category or sub-category.
            var pattern = $"%{request.Keyword.Trim().ToLower()}%";
            items = items.Where(i =>
                EF.Functions.Like(i.Name.ToLower(), pattern)
                || EF.Functions.Like(i.RentalCategory.Name.ToLower(), pattern)
                || (i.RentalSubCategory != null && EF.Functions.Like(i.RentalSubCategory.Name.ToLower(), pattern)));
        }

        return await dbContext.CardsAsync(
            items.OrderByDescending(i => i.CreatedDate).Take(settings.Value.SearchTake),
            request.DistrictIds,
            cancellationToken);
    }

    public async Task<List<RentalCardDto>> Handle(GetRentalBannersQuery request, CancellationToken cancellationToken)
    {
        var withPhotos = await dbContext.VisibleToCustomers()
            .InDistricts(request.DistrictIds)
            .Where(i => i.Media.Any(m => m.MediaType == RentalMediaType.Image))
            .OrderByDescending(i => i.CreatedDate)
            .Take(settings.Value.HomePoolSize)
            .Select(i => i.Id)
            .ToListAsync(cancellationToken);

        // The same featured items all day, different tomorrow.
        var random = new Random(clock.GetUtcNow().UtcDateTime.DayNumber());
        var featured = withPhotos.OrderBy(_ => random.Next()).Take(settings.Value.BannerCount).ToList();
        var cards = (await dbContext.CardsAsync(
                dbContext.RentalItems.Where(i => featured.Contains(i.Id)), request.DistrictIds, cancellationToken))
            .ToDictionary(c => c.Id);
        return featured.Where(cards.ContainsKey).Select(id => cards[id]).ToList();
    }

    public async Task<RentalItemDetailDto> Handle(GetRentalItemDetailQuery request, CancellationToken cancellationToken)
    {
        // Hidden items are simply not found: a switched-off or unverified listing does not exist to customers.
        var item = await dbContext.VisibleToCustomers()
            .AsNoTracking()
            .WithCard()
            .FirstOrDefaultAsync(i => i.Id == request.Id, cancellationToken)
            ?? throw new EntityNotFoundException(nameof(RentalItem), request.Id);

        var card = (await dbContext.CardsAsync(dbContext.RentalItems.Where(i => i.Id == item.Id), [], cancellationToken)).Single();
        var typeName = await dbContext.RentalPriceTypes
            .Where(p => p.Code == item.PriceType)
            .Select(p => p.Name)
            .FirstOrDefaultAsync(cancellationToken);
        var logo = await dbContext.RentalBusinesses
            .Where(b => b.OwnerUserId == item.OwnerUserId)
            .Select(b => b.LogoUrl)
            .FirstOrDefaultAsync(cancellationToken);
        var dto = item.ToDto();

        return new RentalItemDetailDto
        {
            Card = card,
            Description = item.Description,
            SubCategoryName = item.RentalSubCategory?.Name,
            PriceTypeName = typeName ?? item.PriceType.ToString(),
            QuantityOwned = item.QuantityOwned,
            AdvanceType = dto.AdvanceType,
            AdvanceAmount = dto.AdvanceAmount,
            Media = dto.Media,
            Districts = dto.Districts,
            Questions = dto.Questions,
            CancelSteps = dto.CancelSteps,
            CancelUnit = dto.CancelUnit,
            CancelChargeType = dto.CancelChargeType,
            CancelPercentPerDay = dto.CancelPercentPerDay,
            MaxCancelPercent = item.RentalCategory is null ? 0 : RentalCancelLimits.For(item.RentalCategory, item.RentalSubCategory, settings.Value),
            BusinessLogoUrl = logo,
        };
    }

    public async Task<RentalAvailabilityDto> Handle(GetCustomerRentalAvailabilityQuery request, CancellationToken cancellationToken)
    {
        var item = await dbContext.VisibleToCustomers().AsNoTracking().FirstOrDefaultAsync(i => i.Id == request.RentalItemId, cancellationToken)
            ?? throw new EntityNotFoundException(nameof(RentalItem), request.RentalItemId);
        return await dbContext.AvailabilityAsync(item, request.StartDate, request.EndDate, null, cancellationToken);
    }
}

internal static class DateNumbers
{
    /// <summary>Days since 0001-01-01: one number per calendar day, for a daily shuffle.</summary>
    public static int DayNumber(this DateTime moment) => (int)(moment.Ticks / TimeSpan.TicksPerDay);
}
