using Zuno.Domain.Entities;

namespace Zuno.Application.Modules.Catalog.DTOs;

public static class ServiceCategoryMappingExtensions
{
    public static ServiceCategoryDto ToDto(this ServiceCategory category) => new()
    {
        Id = category.Id,
        Name = category.Name,
        Slug = category.Slug,
        Description = category.Description,
        IconUrl = category.IconUrl,
        IconName = category.IconName,
        DisplayOrder = category.DisplayOrder,
        SubCategories = category.SubCategories
            .Where(s => s.IsActive)
            .OrderBy(s => s.DisplayOrder)
            .Select(s => s.ToDto())
            .ToList(),
    };

    public static ServiceSubCategoryDto ToDto(this ServiceSubCategory subCategory) => new()
    {
        Id = subCategory.Id,
        ServiceCategoryId = subCategory.ServiceCategoryId,
        Name = subCategory.Name,
        Slug = subCategory.Slug,
        DisplayOrder = subCategory.DisplayOrder,
    };
}
