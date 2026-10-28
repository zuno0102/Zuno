using MediatR;
using Microsoft.EntityFrameworkCore;
using Zuno.Application.Common.Interfaces;
using Zuno.Application.Modules.Customer.DTOs;
using Zuno.Domain.Enums;

namespace Zuno.Application.Modules.Customer.Queries.SearchBusinesses;

public class SearchBusinessesQueryHandler(IApplicationDbContext dbContext, IPlatformSettings platformSettings)
    : IRequestHandler<SearchBusinessesQuery, List<BusinessSummaryDto>>
{
    public async Task<List<BusinessSummaryDto>> Handle(SearchBusinessesQuery request, CancellationToken cancellationToken)
    {
        var query = dbContext.BusinessOwnerProfiles
            .Include(bp => bp.BusinessAddress)
            .Include(bp => bp.Services).ThenInclude(s => s.ServiceCategory)
            .Include(bp => bp.Services).ThenInclude(s => s.ServiceSubCategory)
            .Where(bp => bp.VerificationStatus == VerificationStatus.Verified)
            .AsQueryable();

        if (request.ServiceCategoryId.HasValue)
        {
            query = query.Where(bp => bp.Services.Any(
                s => s.IsActive && s.ServiceCategoryId == request.ServiceCategoryId.Value));
        }

        if (!string.IsNullOrWhiteSpace(request.Keyword))
        {
            var keyword = request.Keyword.Trim().ToLower();
            query = query.Where(bp => bp.BusinessName.ToLower().Contains(keyword));
        }

        if (request.DistrictIds is { Count: > 0 })
        {
            query = query.Where(bp => bp.Services.Any(
                s => s.IsActive && s.TargetDistricts.Any(t => request.DistrictIds.Contains(t.DistrictId))));
        }

        var businesses = await query.OrderBy(bp => bp.BusinessName).ToListAsync(cancellationToken);

        var levels = platformSettings.Current.BusinessLevels;
        return businesses.Select(bp => bp.ToSummaryDto(levels)).ToList();
    }
}
