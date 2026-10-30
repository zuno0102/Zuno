using MediatR;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Caching.Memory;
using Microsoft.Extensions.Options;
using Zuno.Rent.Application.Common;

namespace Zuno.Rent.Application.Categories;

/// <summary>The rate types the form offers — names, the line under each, and the "/day" suffix — in display order.</summary>
public class GetRentalPriceTypesQuery : IRequest<List<RentalPriceTypeDto>>;

public class GetRentalPriceTypesQueryHandler(
    IRentDbContext dbContext,
    IMemoryCache cache,
    IOptions<RentSettings> settings) : IRequestHandler<GetRentalPriceTypesQuery, List<RentalPriceTypeDto>>
{
    public const string CacheKey = "rent:price-types";

    public async Task<List<RentalPriceTypeDto>> Handle(GetRentalPriceTypesQuery request, CancellationToken cancellationToken)
    {
        if (cache.TryGetValue(CacheKey, out List<RentalPriceTypeDto>? cached) && cached is not null)
        {
            return cached;
        }

        var rows = await dbContext.RentalPriceTypes
            .AsNoTracking()
            .Where(p => p.IsActive)
            .OrderBy(p => p.DisplayOrder)
            .ToListAsync(cancellationToken);

        // Mapped after the read: the code goes out by name ("Daily"), which the database cannot write.
        var types = rows
            .Select(p => new RentalPriceTypeDto
            {
                Code = p.Code.ToString(),
                Name = p.Name,
                Detail = p.Detail,
                UnitSuffix = p.UnitSuffix,
            })
            .ToList();

        cache.Set(CacheKey, types, TimeSpan.FromSeconds(settings.Value.CategoryCacheSeconds));

        return types;
    }
}
