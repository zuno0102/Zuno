using Zuno.Domain.Entities;
using Zuno.Domain.ValueObjects;

namespace Zuno.Application.Modules.Business.DTOs;

public static class BusinessMappingExtensions
{
    public static BusinessProfileDto ToDto(this BusinessOwnerProfile profile) => new()
    {
        Id = profile.Id,
        BusinessName = profile.BusinessName,
        BusinessType = profile.BusinessType,
        GstNumber = profile.GstNumber,
        Description = profile.Description,
        LogoUrl = profile.LogoUrl,
        VerificationStatus = profile.VerificationStatus.ToString(),
        AddressLine1 = profile.BusinessAddress?.Line1,
        AddressLine2 = profile.BusinessAddress?.Line2,
        City = profile.BusinessAddress?.City,
        State = profile.BusinessAddress?.State,
        PostalCode = profile.BusinessAddress?.PostalCode,
        Country = profile.BusinessAddress?.Country,
        Latitude = profile.BusinessAddress?.Latitude,
        Longitude = profile.BusinessAddress?.Longitude,
        Level = profile.Level,
        LevelName = BusinessLevel.Name(profile.Level),
    };

    public static BusinessServiceDto ToDto(this BusinessService service) => new()
    {
        Id = service.Id,
        ServiceCategoryId = service.ServiceCategoryId,
        ServiceCategoryName = service.ServiceCategory.Name,
        ServiceSubCategoryId = service.ServiceSubCategoryId,
        ServiceSubCategoryName = service.ServiceSubCategory?.Name,
        Name = service.Name,
        ItemName = service.ItemName,
        Description = service.Description,
        PriceType = service.PriceType.ToString(),
        Price = service.Price,
        EstimatedDurationMinutes = service.EstimatedDurationMinutes,
        RequiredWorkerCount = service.RequiredWorkerCount,
        IsActive = service.IsActive,
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
            .Select(v => v.ToDto())
            .ToList(),
        Questions = service.Questions.ToQuestionDtos(),
    };

    public static ServiceVariantDto ToDto(this BusinessServiceVariant variant) => new()
    {
        Id = variant.Id,
        Name = variant.Name,
        ServiceSubCategoryId = variant.ServiceSubCategoryId,
        ServiceSubCategoryName = variant.ServiceSubCategory?.Name,
        Description = variant.Description,
        PriceType = variant.PriceType.ToString(),
        Price = variant.Price,
        EstimatedDurationMinutes = variant.EstimatedDurationMinutes,
        IsActive = variant.IsActive,
        Media = variant.Media
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
    };

    public static BusinessWorkerDto ToDto(this BusinessWorker businessWorker, string availabilityStatus = "Active") => new()
    {
        Id = businessWorker.Id,
        WorkerProfileId = businessWorker.WorkerProfileId,
        WorkerName = $"{businessWorker.WorkerProfile.User.FirstName} {businessWorker.WorkerProfile.User.LastName}",
        WorkerEmail = businessWorker.WorkerProfile.User.Email,
        WorkerPhone = businessWorker.WorkerProfile.User.PhoneNumber,
        Status = businessWorker.AssignmentStatus.ToString(),
        AvailabilityStatus = availabilityStatus,
        InvitedAt = businessWorker.InvitedAt,
        RespondedAt = businessWorker.RespondedAt,
    };

    public static WorkerInvitationDto ToInvitationDto(this BusinessWorker businessWorker) => new()
    {
        Id = businessWorker.Id,
        BusinessOwnerProfileId = businessWorker.BusinessOwnerProfileId,
        BusinessName = businessWorker.BusinessOwnerProfile.BusinessName,
        BusinessLogoUrl = businessWorker.BusinessOwnerProfile.LogoUrl,
        Status = businessWorker.AssignmentStatus.ToString(),
        InvitedAt = businessWorker.InvitedAt,
        RespondedAt = businessWorker.RespondedAt,
    };
}
