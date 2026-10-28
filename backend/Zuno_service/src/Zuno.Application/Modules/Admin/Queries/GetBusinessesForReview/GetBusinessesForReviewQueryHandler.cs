using MediatR;
using Microsoft.EntityFrameworkCore;
using Zuno.Application.Common.Interfaces;
using Zuno.Application.Modules.Admin.DTOs;
using Zuno.Domain.Enums;

namespace Zuno.Application.Modules.Admin.Queries.GetBusinessesForReview;

public class GetBusinessesForReviewQueryHandler(IApplicationDbContext dbContext)
    : IRequestHandler<GetBusinessesForReviewQuery, List<BusinessReviewDto>>
{
    public async Task<List<BusinessReviewDto>> Handle(
        GetBusinessesForReviewQuery request,
        CancellationToken cancellationToken)
    {
        var query = dbContext.BusinessOwnerProfiles
            .Include(p => p.User)
            .Include(p => p.BusinessAddress)
            .Include(p => p.Services)
            .AsQueryable();

        if (Enum.TryParse<VerificationStatus>(request.Status, ignoreCase: true, out var status))
        {
            query = query.Where(p => p.VerificationStatus == status);
        }

        var profiles = await query
            // Oldest first: someone who registered a week ago has been invisible the longest.
            .OrderBy(p => p.CreatedDate)
            .ToListAsync(cancellationToken);

        return profiles.Select(p => p.ToReviewDto()).ToList();
    }
}
