using Zuno.Rent.Domain.Entities;
using Zuno.Rent.Domain.Enums;

namespace Zuno.Rent.Application.Common;

/// <summary>Turns a loaded rent item (category, sub-category, media, districts) into what the app shows.</summary>
internal static class RentalItemMapper
{
    public static RentalItemDto ToDto(this RentalItem item) => new()
    {
        Id = item.Id,
        RentalCategoryId = item.RentalCategoryId,
        RentalCategoryName = item.RentalCategory?.Name ?? string.Empty,
        RentalSubCategoryId = item.RentalSubCategoryId,
        RentalSubCategoryName = item.RentalSubCategory?.Name,
        Name = item.Name,
        Description = item.Description,
        PriceType = item.PriceType.ToString(),
        Price = item.Price,
        QuantityOwned = item.QuantityOwned,
        AdvanceType = item.AdvanceType.ToString(),
        AdvanceAmount = item.AdvanceAmount,
        IsAvailable = item.IsAvailable,
        Media = item.Media
            .Where(m => !m.IsDeleted)
            .OrderBy(m => m.MediaType == RentalMediaType.Video)
            .ThenBy(m => m.SortOrder)
            .Select(m => new RentalItemMediaDto
            {
                Id = m.Id,
                MediaType = m.MediaType.ToString(),
                Url = m.Url,
                SortOrder = m.SortOrder,
            })
            .ToList(),
        Districts = item.Districts
            .Where(d => !d.IsDeleted && d.District is not null)
            .Select(d => new RentalItemDistrictDto
            {
                Id = d.DistrictId,
                Name = d.District.Name,
                StateId = d.District.StateId,
                StateName = d.District.State?.Name ?? string.Empty,
            })
            .OrderBy(d => d.Name)
            .ToList(),
        Questions = item.Questions
            .Where(q => !q.IsDeleted)
            .OrderBy(q => q.SortOrder)
            .Select(q => new RentalItemQuestionDto { Id = q.Id, Prompt = q.Prompt, IsRequired = q.IsRequired })
            .ToList(),
    };
}
