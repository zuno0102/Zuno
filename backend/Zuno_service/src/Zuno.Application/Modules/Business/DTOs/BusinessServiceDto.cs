namespace Zuno.Application.Modules.Business.DTOs;

public class BusinessServiceDto
{
    public Guid Id { get; set; }

    public Guid ServiceCategoryId { get; set; }

    public string ServiceCategoryName { get; set; } = string.Empty;

    public Guid? ServiceSubCategoryId { get; set; }

    public string? ServiceSubCategoryName { get; set; }

    public string Name { get; set; } = string.Empty;

    public string? ItemName { get; set; }

    public string? Description { get; set; }

    public string PriceType { get; set; } = string.Empty;

    public decimal Price { get; set; }

    public short? EstimatedDurationMinutes { get; set; }

    public int RequiredWorkerCount { get; set; } = 1;

    public bool IsActive { get; set; }

    public List<ServiceMediaDto> Media { get; set; } = [];

    public List<ServiceDistrictDto> TargetDistricts { get; set; } = [];

    /// <summary>What this service asks a customer before they book.</summary>
    public List<ServiceQuestionDto> Questions { get; set; } = [];

    public List<ServiceVariantDto> Variants { get; set; } = [];
}
