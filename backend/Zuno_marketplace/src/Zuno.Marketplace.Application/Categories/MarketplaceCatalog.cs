using MediatR;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Options;
using Zuno.Marketplace.Application.Common;
using Zuno.Marketplace.Domain.Entities;

namespace Zuno.Marketplace.Application.Categories;

/// <summary>The categories a business can post in, each with the details it asks for, in display order.</summary>
/// <param name="IncludeInactive">The super admin's view: switched-off categories and fields too.</param>
public record GetMarketplaceCategoriesQuery(bool IncludeInactive = false) : IRequest<List<MarketplaceCategoryDto>>;

/// <summary>The post kinds, statuses and limits the Marketplace screens are drawn from.</summary>
public record GetMarketplaceOptionsQuery : IRequest<MarketplaceOptionsDto>;

public class MarketplaceCatalogHandlers(
    IMarketplaceDbContext dbContext,
    MarketplaceReference reference,
    IOptions<MarketplaceSettings> settings) :
    IRequestHandler<GetMarketplaceCategoriesQuery, List<MarketplaceCategoryDto>>,
    IRequestHandler<GetMarketplaceOptionsQuery, MarketplaceOptionsDto>
{
    public async Task<List<MarketplaceCategoryDto>> Handle(GetMarketplaceCategoriesQuery request, CancellationToken cancellationToken)
    {
        var categories = await reference.CategoriesAsync(cancellationToken);
        return categories
            .Where(c => request.IncludeInactive || c.IsActive)
            .Select(c => c.ToDto(request.IncludeInactive))
            .ToList();
    }

    public async Task<MarketplaceOptionsDto> Handle(GetMarketplaceOptionsQuery request, CancellationToken cancellationToken)
    {
        var limits = settings.Value;
        var kinds = await dbContext.PostKinds.AsNoTracking()
            .Where(k => k.IsActive)
            .OrderBy(k => k.DisplayOrder)
            .ToListAsync(cancellationToken);
        var statuses = await dbContext.PostStatuses.AsNoTracking().OrderBy(s => s.DisplayOrder).ToListAsync(cancellationToken);

        return new MarketplaceOptionsDto
        {
            Kinds = kinds.Select(k => new MarketplaceOptionDto { Code = k.Code.ToString(), Name = k.Name }).ToList(),
            Statuses = statuses.Select(s => new MarketplaceOptionDto { Code = s.Code.ToString(), Name = s.Name, Tone = s.Tone }).ToList(),
            ImageSlots = limits.ImageSlots,
            MaxFoodOfferHours = limits.MaxFoodOfferHours,
            MaxAdDays = limits.MaxAdDays,
            MaxPrice = limits.MaxPrice,
            MaxQuantity = limits.MaxQuantity,
        };
    }
}

internal static class MarketplaceCategoryMapper
{
    public static MarketplaceCategoryDto ToDto(this MarketplaceCategory category, bool includeInactiveFields) => new()
    {
        Id = category.Id,
        Name = category.Name,
        Slug = category.Slug,
        IconName = category.IconName,
        Kind = category.Kind.ToString(),
        AllowsWholesale = category.AllowsWholesale,
        DisplayOrder = category.DisplayOrder,
        IsActive = category.IsActive,
        Fields = category.Fields
            .Where(f => !f.IsDeleted && (includeInactiveFields || f.IsActive))
            .OrderBy(f => f.DisplayOrder)
            .ThenBy(f => f.Label)
            .Select(f => new MarketplaceCategoryFieldDto
            {
                Id = f.Id,
                Key = f.Key,
                Label = f.Label,
                FieldType = f.FieldType.ToString(),
                Options = f.Options,
                Unit = f.Unit,
                IsRequired = f.IsRequired,
                DisplayOrder = f.DisplayOrder,
                IsActive = f.IsActive,
            })
            .ToList(),
    };
}
