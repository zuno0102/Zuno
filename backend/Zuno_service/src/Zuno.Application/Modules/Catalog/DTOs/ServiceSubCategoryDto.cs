namespace Zuno.Application.Modules.Catalog.DTOs;

public class ServiceSubCategoryDto
{
    public Guid Id { get; set; }

    public Guid ServiceCategoryId { get; set; }

    public string Name { get; set; } = string.Empty;

    public string Slug { get; set; } = string.Empty;

    public short DisplayOrder { get; set; }
}
