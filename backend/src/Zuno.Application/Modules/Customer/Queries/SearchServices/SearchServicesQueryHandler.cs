using MediatR;
using Microsoft.EntityFrameworkCore;
using Zuno.Application.Common.Interfaces;
using Zuno.Application.Modules.Customer.DTOs;
using Zuno.Domain.Enums;
using Zuno.Domain.ValueObjects;

namespace Zuno.Application.Modules.Customer.Queries.SearchServices;

public class SearchServicesQueryHandler(IApplicationDbContext dbContext, IPlatformSettings platformSettings)
    : IRequestHandler<SearchServicesQuery, List<ServiceListingDto>>
{
    public async Task<List<ServiceListingDto>> Handle(
        SearchServicesQuery request,
        CancellationToken cancellationToken)
    {
        var query = dbContext.BusinessServices
            .Where(s => s.IsActive)
            // A customer must never be shown a business an admin has not cleared, however good
            // its services look.
            .Where(s => s.BusinessOwnerProfile.VerificationStatus == VerificationStatus.Verified);

        if (request.CategoryId is { } categoryId)
        {
            query = query.Where(s => s.ServiceCategoryId == categoryId);
        }

        if (!string.IsNullOrWhiteSpace(request.Keyword))
        {
            var keyword = request.Keyword.Trim().ToLower();
            query = query.Where(s =>
                s.Name.ToLower().Contains(keyword)
                || s.BusinessOwnerProfile.BusinessName.ToLower().Contains(keyword));
        }

        if (request.DistrictIds is { Count: > 0 } districtIds)
        {
            query = query.Where(s => s.TargetDistricts.Any(d => districtIds.Contains(d.DistrictId)));
        }

        var listings = await query
            // Best-regarded first, then the busiest — a brand-new listing should not outrank a
            // business with a track record simply because it was added later.
            .OrderByDescending(s => s.BusinessOwnerProfile.CustomerRatingAverage ?? 0)
            .ThenByDescending(s => s.BusinessOwnerProfile.CompletedJobCount)
            .ThenBy(s => s.Price)
            // Held inside the configured bounds: an uncapped take let one request pull the whole catalogue.
            .Take(platformSettings.Current.ServiceSearchPageSize(request.Take))
            .Select(s => new ServiceListingDto
            {
                Id = s.Id,
                Name = s.Name,
                Description = s.Description,
                ServiceCategoryName = s.ServiceCategory.Name,
                ServiceCategoryId = s.ServiceCategoryId,
                Price = s.Price,
                PriceType = s.PriceType.ToString(),
                ImageUrl = s.Media
                    .OrderBy(m => m.SortOrder)
                    .Select(m => m.Url)
                    .FirstOrDefault(),
                BusinessOwnerProfileId = s.BusinessOwnerProfileId,
                BusinessName = s.BusinessOwnerProfile.BusinessName,
                BusinessLogoUrl = s.BusinessOwnerProfile.LogoUrl,
                City = s.BusinessOwnerProfile.BusinessAddress!.City,
                Level = s.BusinessOwnerProfile.Level,
                RatingAverage = s.BusinessOwnerProfile.CustomerRatingAverage,
                ReviewCount = s.BusinessOwnerProfile.CustomerReviewCount,
            })
            .ToListAsync(cancellationToken);

        // Applied after materialising: the level names are platform settings and the projection above runs as
        // SQL. Doing it here keeps the wording of a level on the server, rather than duplicated
        // into a switch statement in every client.
        var levels = platformSettings.Current.BusinessLevels;
        foreach (var listing in listings)
        {
            listing.LevelName = levels.Name(listing.Level);
        }

        return listings;
    }
}
