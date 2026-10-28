using Zuno.Domain.Entities;

namespace Zuno.Application.Modules.Catalog.DTOs;

/// <summary>A sub-category as the app owner sees it, hidden ones included.</summary>
public class AdminServiceSubCategoryDto
{
    public Guid Id { get; set; }

    public Guid ServiceCategoryId { get; set; }

    public string Name { get; set; } = string.Empty;

    public string Slug { get; set; } = string.Empty;

    public short DisplayOrder { get; set; }

    /// <summary>False means hidden from the pickers. Nothing here is ever deleted.</summary>
    public bool IsActive { get; set; }
}

/// <summary>
/// A category as the app owner sees it: hidden rows included, and how much is riding on it.
/// </summary>
/// <remarks>
/// Separate from <see cref="ServiceCategoryDto"/> on purpose. The public one hides inactive rows
/// and carries no <c>IsActive</c> flag at all, which is exactly right for a customer and exactly
/// wrong for the person deciding what to hide.
/// </remarks>
public class AdminServiceCategoryDto
{
    public Guid Id { get; set; }

    public string Name { get; set; } = string.Empty;

    public string Slug { get; set; } = string.Empty;

    public string? Description { get; set; }

    public string? IconUrl { get; set; }

    /// <summary>Which built-in icon the apps draw for this category.</summary>
    public string? IconName { get; set; }

    public short DisplayOrder { get; set; }

    public bool IsActive { get; set; }

    /// <summary>
    /// How many services businesses have already listed under this category.
    /// </summary>
    /// <remarks>
    /// Shown next to the Hide button so the decision is made with the consequence in view.
    /// Hiding a category with 14 services behind it is a different act from hiding an empty one.
    /// </remarks>
    public int ServiceCount { get; set; }

    public List<AdminServiceSubCategoryDto> SubCategories { get; set; } = [];
}

public static class AdminCatalogMappingExtensions
{
    public static AdminServiceSubCategoryDto ToAdminDto(this ServiceSubCategory subCategory) => new()
    {
        Id = subCategory.Id,
        ServiceCategoryId = subCategory.ServiceCategoryId,
        Name = subCategory.Name,
        Slug = subCategory.Slug,
        DisplayOrder = subCategory.DisplayOrder,
        IsActive = subCategory.IsActive,
    };

    /// <param name="serviceCount">
    /// Counted by the caller rather than read off the navigation: loading every business service
    /// to count them would pull the whole catalogue into memory for a number.
    /// </param>
    public static AdminServiceCategoryDto ToAdminDto(
        this ServiceCategory category,
        int serviceCount = 0) => new()
    {
        Id = category.Id,
        Name = category.Name,
        Slug = category.Slug,
        Description = category.Description,
        IconUrl = category.IconUrl,
        IconName = category.IconName,
        DisplayOrder = category.DisplayOrder,
        IsActive = category.IsActive,
        ServiceCount = serviceCount,
        // Hidden sub-categories are kept: this is the one screen that has to show them, since it
        // is the only place they can be brought back.
        SubCategories = [.. category.SubCategories
            .OrderBy(s => s.DisplayOrder)
            .ThenBy(s => s.Name)
            .Select(s => s.ToAdminDto())],
    };
}
