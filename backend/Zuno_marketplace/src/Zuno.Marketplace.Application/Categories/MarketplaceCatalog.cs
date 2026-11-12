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
        var tradeModes = await dbContext.TradeModes.AsNoTracking().OrderBy(t => t.DisplayOrder).ToListAsync(cancellationToken);
        var conditions = await dbContext.ItemConditions.AsNoTracking().OrderBy(c => c.DisplayOrder).ToListAsync(cancellationToken);

        return new MarketplaceOptionsDto
        {
            Kinds = kinds.Select(k => new MarketplaceOptionDto { Code = k.Code.ToString(), Name = k.Name }).ToList(),
            Statuses = statuses.Select(s => new MarketplaceOptionDto { Code = s.Code.ToString(), Name = s.Name, Tone = s.Tone }).ToList(),
            TradeModes = tradeModes.Select(t => new MarketplaceOptionDto { Code = t.Code.ToString(), Name = t.Name, Detail = t.Detail }).ToList(),
            Conditions = conditions.Select(c => new MarketplaceOptionDto { Code = c.Code.ToString(), Name = c.Name, Detail = c.Detail }).ToList(),
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
    /// <param name="includeInactive">The super admin's view: switched-off sub-categories and fields too.</param>
    public static MarketplaceCategoryDto ToDto(this MarketplaceCategory category, bool includeInactive) => new()
    {
        Id = category.Id,
        Name = category.Name,
        ShortName = string.IsNullOrWhiteSpace(category.ShortName) ? category.Name : category.ShortName,
        Description = category.Description,
        Slug = category.Slug,
        IconName = category.IconName,
        Kind = category.Kind.ToString(),
        TradeMode = category.TradeMode.ToString(),
        TracksStock = category.TracksStock,
        DisplayOrder = category.DisplayOrder,
        IsActive = category.IsActive,
        SubCategories = category.SubCategories
            .Where(s => !s.IsDeleted && (includeInactive || s.IsActive))
            .OrderBy(s => s.DisplayOrder)
            .ThenBy(s => s.Name)
            .Select(s => new MarketplaceSubCategoryDto
            {
                Id = s.Id,
                Name = s.Name,
                Slug = s.Slug,
                IconName = s.IconName,
                DisplayOrder = s.DisplayOrder,
                IsActive = s.IsActive,
            })
            .ToList(),
        Fields = category.Fields
            .Where(f => !f.IsDeleted && (includeInactive || f.IsActive))
            .Where(f => includeInactive || f.SubCategoryId is null
                || category.SubCategories.Any(s => s.Id == f.SubCategoryId && s.IsActive && !s.IsDeleted))
            // The whole category's details first, then each sub-category's, in the sub-categories' order.
            .OrderBy(f => f.SubCategoryId is null
                ? -1
                : category.SubCategories.FirstOrDefault(s => s.Id == f.SubCategoryId)?.DisplayOrder ?? short.MaxValue)
            .ThenBy(f => f.DisplayOrder)
            .ThenBy(f => f.Label)
            .Select(f => new MarketplaceCategoryFieldDto
            {
                Id = f.Id,
                SubCategoryId = f.SubCategoryId,
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
