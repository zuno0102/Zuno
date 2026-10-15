using MediatR;
using Microsoft.EntityFrameworkCore;
using Zuno.Application.Common.Interfaces;
using Zuno.Application.Modules.Catalog.DTOs;

namespace Zuno.Application.Modules.Catalog.Queries.GetServiceCategories;

public class GetServiceCategoriesQueryHandler(IApplicationDbContext dbContext)
    : IRequestHandler<GetServiceCategoriesQuery, List<ServiceCategoryDto>>
{
    public async Task<List<ServiceCategoryDto>> Handle(GetServiceCategoriesQuery request, CancellationToken cancellationToken)
    {
        var categories = await dbContext.ServiceCategories
            .Include(c => c.SubCategories)
            .Where(c => c.IsActive)
            .OrderBy(c => c.DisplayOrder)
            .ToListAsync(cancellationToken);

        return categories.Select(c => c.ToDto()).ToList();
    }
}
