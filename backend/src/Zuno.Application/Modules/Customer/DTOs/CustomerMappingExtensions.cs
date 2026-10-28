using Zuno.Application.Modules.Business.DTOs;
using Zuno.Domain.Entities;
using Zuno.Domain.ValueObjects;

namespace Zuno.Application.Modules.Customer.DTOs;

public static class CustomerMappingExtensions
{
    public static BusinessSummaryDto ToSummaryDto(this BusinessOwnerProfile profile, LevelLadder levels) => new()
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
        LevelName = levels.Name(profile.Level),
        RatingAverage = profile.CustomerRatingAverage,
        ReviewCount = profile.CustomerReviewCount,
        CompletedJobCount = profile.CompletedJobCount,
        // The cheapest active service, so a card can say what this costs to start with rather
        // than making someone open it to find out.
        StartingPrice = profile.Services
            .Where(s => s.IsActive && s.Price > 0)
            .Select(s => (decimal?)s.Price)
            .DefaultIfEmpty(null)
            .Min(),
    };

    public static BusinessDetailDto ToDetailDto(this BusinessOwnerProfile profile) => new()
    {
        Id = profile.Id,
        BusinessName = profile.BusinessName,
        Description = profile.Description,
        LogoUrl = profile.LogoUrl,
        AddressLine1 = profile.BusinessAddress?.Line1,
        City = profile.BusinessAddress?.City,
        State = profile.BusinessAddress?.State,
        Country = profile.BusinessAddress?.Country,
        Services = profile.Services
            .Where(s => s.IsActive)
            .Select(s => s.ToCustomerServiceDto())
            .ToList(),
    };

    public static ServiceDetailDto ToServiceDetailDto(this BusinessService service, LevelLadder levels) => new()
    {
        Service = service.ToCustomerServiceDto(),
        Business = service.BusinessOwnerProfile.ToSummaryDto(levels),
    };

    public static CustomerServiceDto ToCustomerServiceDto(this BusinessService service) => new()
    {
        Id = service.Id,
        ServiceCategoryName = service.ServiceCategory.Name,
        Name = service.Name,
        Description = service.Description,
        PriceType = service.PriceType.ToString(),
        Price = service.Price,
        EstimatedDurationMinutes = service.EstimatedDurationMinutes,
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
