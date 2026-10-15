namespace Zuno.Application.Modules.Customer.DTOs;

public class ServiceVariantDto
{
    public Guid Id { get; set; }

    public string Name { get; set; } = string.Empty;

    public Guid? ServiceSubCategoryId { get; set; }

    /// <summary>Shown instead of the id — "Kitchen cleaning". Null on older items.</summary>
    public string? ServiceSubCategoryName { get; set; }

    public string? Description { get; set; }

    public string PriceType { get; set; } = string.Empty;

    public decimal Price { get; set; }

    public short? EstimatedDurationMinutes { get; set; }

    public List<ServiceMediaDto> Media { get; set; } = [];
}
