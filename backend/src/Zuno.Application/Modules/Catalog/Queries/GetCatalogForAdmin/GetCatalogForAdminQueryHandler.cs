using MediatR;
using Microsoft.EntityFrameworkCore;
using Zuno.Application.Common.Interfaces;
using Zuno.Application.Modules.Catalog.DTOs;

namespace Zuno.Application.Modules.Catalog.Queries.GetCatalogForAdmin;

public class GetCatalogForAdminQueryHandler(IApplicationDbContext dbContext)
    : IRequestHandler<GetCatalogForAdminQuery, List<AdminServiceCategoryDto>>
{
    public async Task<List<AdminServiceCategoryDto>> Handle(
        GetCatalogForAdminQuery request,
        CancellationToken cancellationToken)
    {
        var categories = await dbContext.ServiceCategories
            .Include(c => c.SubCategories)
            .OrderBy(c => c.DisplayOrder)
            .ThenBy(c => c.Name)
            .ToListAsync(cancellationToken);

        // One grouped count rather than a count per category. The alternative — including
        // BusinessServices — would load every service row in the product to produce a number.
        var serviceCounts = await dbContext.BusinessServices
            .GroupBy(s => s.ServiceCategoryId)
            .Select(g => new { CategoryId = g.Key, Count = g.Count() })
            .ToDictionaryAsync(g => g.CategoryId, g => g.Count, cancellationToken);

        return [.. categories.Select(c =>
            c.ToAdminDto(serviceCounts.TryGetValue(c.Id, out var count) ? count : 0))];
    }
}
