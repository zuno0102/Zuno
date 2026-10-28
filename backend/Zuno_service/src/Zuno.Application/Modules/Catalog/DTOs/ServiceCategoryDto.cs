namespace Zuno.Application.Modules.Catalog.DTOs;

public class ServiceCategoryDto
{
    public Guid Id { get; set; }

    public string Name { get; set; } = string.Empty;

    public string Slug { get; set; } = string.Empty;

    public string? Description { get; set; }

    public string? IconUrl { get; set; }

    /// <summary>Which built-in icon the apps draw for this category, or null to let them guess.</summary>
    public string? IconName { get; set; }

    public short DisplayOrder { get; set; }

    /// <summary>The narrower kinds of work offered inside this category.</summary>
    public List<ServiceSubCategoryDto> SubCategories { get; set; } = [];
}
