using MediatR;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Caching.Memory;
using Microsoft.Extensions.Options;
using Zuno.Rent.Application.Common;

namespace Zuno.Rent.Application.Categories;

/// <summary>The active rent categories, each with its active sub-categories, in display order.</summary>
public class GetRentalCategoriesQuery : IRequest<List<RentalCategoryDto>>;

public class GetRentalCategoriesQueryHandler(
    IRentDbContext dbContext,
    IMemoryCache cache,
    IOptions<RentSettings> settings) : IRequestHandler<GetRentalCategoriesQuery, List<RentalCategoryDto>>
{
    public const string CacheKey = "rent:categories";

    public async Task<List<RentalCategoryDto>> Handle(GetRentalCategoriesQuery request, CancellationToken cancellationToken)
    {
        if (cache.TryGetValue(CacheKey, out List<RentalCategoryDto>? cached) && cached is not null)
        {
            return cached;
        }

        var ceiling = settings.Value.CancelPercentCeiling;

        // The same for every business, so read once and cached rather than per call.
        var categories = await dbContext.RentalCategories
            .AsNoTracking()
            .Where(c => c.IsActive)
            .OrderBy(c => c.DisplayOrder)
            .ThenBy(c => c.Name)
            .Select(c => new RentalCategoryDto
            {
                Id = c.Id,
                Name = c.Name,
                Slug = c.Slug,
                IconName = c.IconName,
                MaxCancelPercent = c.MaxCancelPercent < ceiling ? c.MaxCancelPercent : ceiling,
                SubCategories = c.SubCategories
                    .Where(s => s.IsActive && !s.IsDeleted)
                    .OrderBy(s => s.DisplayOrder)
                    .ThenBy(s => s.Name)
                    .Select(s => new RentalSubCategoryDto
                    {
                        Id = s.Id,
                        Name = s.Name,
                        Slug = s.Slug,
                        MaxCancelPercent = (s.MaxCancelPercent ?? c.MaxCancelPercent) < ceiling
                            ? s.MaxCancelPercent ?? c.MaxCancelPercent
                            : ceiling,
                    })
                    .ToList(),
            })
            .ToListAsync(cancellationToken);

        cache.Set(CacheKey, categories, TimeSpan.FromSeconds(settings.Value.CategoryCacheSeconds));

        return categories;
    }
}
