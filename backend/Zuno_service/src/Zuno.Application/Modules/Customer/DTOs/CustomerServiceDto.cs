namespace Zuno.Application.Modules.Customer.DTOs;

public class CustomerServiceDto
{
    public Guid Id { get; set; }

    public string ServiceCategoryName { get; set; } = string.Empty;

    public string Name { get; set; } = string.Empty;

    public string? Description { get; set; }

    public string PriceType { get; set; } = string.Empty;

    public decimal Price { get; set; }

    public short? EstimatedDurationMinutes { get; set; }

    public List<ServiceMediaDto> Media { get; set; } = [];

    public List<ServiceDistrictDto> TargetDistricts { get; set; } = [];

    public List<ServiceVariantDto> Variants { get; set; } = [];

    /// <summary>
    /// What this business needs to know before it can staff the job — the boxes the booking form
    /// draws.
    /// </summary>
    /// <remarks>
    /// Empty for every service that has never had any, which is all of them until a business
    /// writes some. The booking form then shows no extra section and behaves exactly as before.
    /// </remarks>
    public List<Zuno.Application.Modules.Business.DTOs.ServiceQuestionDto> Questions { get; set; } = [];
}
