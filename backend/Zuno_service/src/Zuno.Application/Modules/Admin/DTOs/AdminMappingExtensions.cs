using Zuno.Domain.Entities;

namespace Zuno.Application.Modules.Admin.DTOs;

public static class AdminMappingExtensions
{
    public static BusinessReviewDto ToReviewDto(this BusinessOwnerProfile profile) => new()
    {
        Id = profile.Id,
        BusinessName = profile.BusinessName,
        BusinessType = profile.BusinessType,
        GstNumber = profile.GstNumber,
        Description = profile.Description,
        LogoUrl = profile.LogoUrl,
        City = profile.BusinessAddress?.City,
        State = profile.BusinessAddress?.State,
        OwnerName = profile.User is null
            ? string.Empty
            : $"{profile.User.FirstName} {profile.User.LastName}".Trim(),
        OwnerEmail = profile.User?.Email,
        OwnerPhone = profile.User?.PhoneNumber,
        VerificationStatus = profile.VerificationStatus.ToString(),
        VerifiedAt = profile.VerifiedAt,
        ActiveServiceCount = profile.Services.Count(s => s.IsActive),
        CompletedJobCount = profile.CompletedJobCount,
        OpenDisputeCount = profile.OpenDisputeCount,
        RegisteredAt = profile.CreatedDate,
    };
}
