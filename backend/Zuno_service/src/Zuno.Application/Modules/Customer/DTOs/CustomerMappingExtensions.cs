using Zuno.Application.Common.Services;
using Zuno.Application.Common.Settings;
using Zuno.Application.Modules.Business.DTOs;
using Zuno.Domain.Entities;

namespace Zuno.Application.Modules.Customer.DTOs;

public static class CustomerMappingExtensions
{
    public static BusinessSummaryDto ToSummaryDto(this BusinessOwnerProfile profile, PlatformRules rules)
    {
        var lines = BusinessStanding.Lines(profile, rules);
        return new BusinessSummaryDto
        {
            Id = profile.Id,
            BusinessName = profile.BusinessName,
            Description = profile.Description,
            LogoUrl = profile.LogoUrl,
            City = profile.BusinessAddress?.City,
            State = profile.BusinessAddress?.State,
            ServiceCategoryNames = profile.Services
                .Where(s => s.IsActive)
                .Select(s => s.ServiceCategory.Name)
                .Distinct()
                .ToList(),
            Level = profile.Level,
            LevelName = rules.BusinessLevels.Name(profile.Level),
            RatingAverage = profile.CustomerRatingAverage,
            ReviewCount = profile.CustomerReviewCount,
            ServiceRatingAverage = lines.ServiceRatingAverage,
            ServiceRatingCount = lines.ServiceRatingCount,
            RentRatingAverage = lines.RentRatingAverage,
            RentRatingCount = lines.RentRatingCount,
            CompletedJobCount = profile.CompletedJobCount,
            // The cheapest active service, so a card can say what this costs to start with rather
            // than making someone open it to find out.
            StartingPrice = profile.Services
                .Where(s => s.IsActive && s.Price > 0)
                .Select(s => (decimal?)s.Price)
                .DefaultIfEmpty(null)
                .Min(),
        };
    }

    public static BusinessDetailDto ToDetailDto(this BusinessOwnerProfile profile, PlatformRules rules)
    {
        var lines = BusinessStanding.Lines(profile, rules);
        return new BusinessDetailDto
        {
            Id = profile.Id,
            BusinessName = profile.BusinessName,
            Description = profile.Description,
            LogoUrl = profile.LogoUrl,
            AddressLine1 = profile.BusinessAddress?.Line1,
            City = profile.BusinessAddress?.City,
            State = profile.BusinessAddress?.State,
            Country = profile.BusinessAddress?.Country,
            RatingAverage = profile.CustomerRatingAverage,
            ReviewCount = profile.CustomerReviewCount,
            ServiceRatingAverage = lines.ServiceRatingAverage,
            ServiceRatingCount = lines.ServiceRatingCount,
            RentRatingAverage = lines.RentRatingAverage,
            RentRatingCount = lines.RentRatingCount,
            Services = profile.Services
                .Where(s => s.IsActive)
                .Select(s => s.ToCustomerServiceDto(rules))
                .ToList(),
        };
    }

    public static ServiceDetailDto ToServiceDetailDto(this BusinessService service, PlatformRules rules) => new()
    {
        Service = service.ToCustomerServiceDto(rules),
        Business = service.BusinessOwnerProfile.ToSummaryDto(rules),
    };

    public static CustomerServiceDto ToCustomerServiceDto(this BusinessService service, PlatformRules rules) => new()
    {
        Id = service.Id,
        ServiceCategoryName = service.ServiceCategory.Name,
        Name = service.Name,
        Description = service.Description,
        PriceType = service.PriceType.ToString(),
        Price = service.Price,
        EstimatedDurationMinutes = service.EstimatedDurationMinutes,
        RatingAverage = rules.FairRating(service.RatingSum, service.RatingCount),
        RatingCount = service.RatingCount,
        Media = service.Media
            .OrderBy(m => m.MediaType)
            .ThenBy(m => m.SortOrder)
            .Select(m => new ServiceMediaDto
            {
                Id = m.Id,
                MediaType = m.MediaType.ToString(),
                Url = m.Url,
                SortOrder = m.SortOrder,
            })
            .ToList(),
        TargetDistricts = service.TargetDistricts
            .Select(t => new ServiceDistrictDto
            {
                Id = t.District.Id,
                Name = t.District.Name,
                StateId = t.District.StateId,
                StateName = t.District.State.Name,
            })
            .ToList(),
        Variants = service.Variants
            .Where(v => v.IsActive)
            .Select(v => new ServiceVariantDto
            {
                Id = v.Id,
                Name = v.Name,
                ServiceSubCategoryId = v.ServiceSubCategoryId,
                ServiceSubCategoryName = v.ServiceSubCategory != null
                    ? v.ServiceSubCategory.Name
                    : null,
                Description = v.Description,
                PriceType = v.PriceType.ToString(),
                Price = v.Price,
                EstimatedDurationMinutes = v.EstimatedDurationMinutes,
                Media = v.Media
                    .OrderBy(m => m.MediaType)
                    .ThenBy(m => m.SortOrder)
                    .Select(m => new ServiceMediaDto
                    {
                        Id = m.Id,
                        MediaType = m.MediaType.ToString(),
                        Url = m.Url,
                        SortOrder = m.SortOrder,
                    })
                    .ToList(),
            })
            .ToList(),
        Questions = service.Questions.ToQuestionDtos(),
    };
}
