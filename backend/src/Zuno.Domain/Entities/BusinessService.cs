using Zuno.Domain.Common;
using Zuno.Domain.Enums;

namespace Zuno.Domain.Entities;

public class BusinessService : BaseEntity
{
    public Guid BusinessOwnerProfileId { get; set; }

    public BusinessOwnerProfile BusinessOwnerProfile { get; set; } = null!;

    public Guid ServiceCategoryId { get; set; }

    public ServiceCategory ServiceCategory { get; set; } = null!;

    public string Name { get; set; } = string.Empty;

    public string? ItemName { get; set; }

    public string? Description { get; set; }

    public PriceType PriceType { get; set; } = PriceType.Fixed;

    public decimal Price { get; set; }

    public short? EstimatedDurationMinutes { get; set; }

    public bool IsActive { get; set; } = true;

    public int RequiredWorkerCount { get; set; } = 1;

    public ICollection<BusinessServiceMedia> Media { get; set; } = new List<BusinessServiceMedia>();

    /// <summary>What the business needs to know from a customer before it can staff this job.</summary>
    public ICollection<BusinessServiceQuestion> Questions { get; set; } = new List<BusinessServiceQuestion>();

    public ICollection<BusinessServiceDistrict> TargetDistricts { get; set; } = new List<BusinessServiceDistrict>();

    public ICollection<BusinessServiceVariant> Variants { get; set; } = new List<BusinessServiceVariant>();
}
