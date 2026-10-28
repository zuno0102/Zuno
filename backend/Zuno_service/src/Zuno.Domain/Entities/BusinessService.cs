using Zuno.Domain.Common;
using Zuno.Domain.Enums;

namespace Zuno.Domain.Entities;

public class BusinessService : BaseEntity
{
    public Guid BusinessOwnerProfileId { get; set; }

    public BusinessOwnerProfile BusinessOwnerProfile { get; set; } = null!;

    public Guid ServiceCategoryId { get; set; }

    public ServiceCategory ServiceCategory { get; set; } = null!;

    /// <summary>
    /// The trade within the category: "Pipe leak repair" under Plumbing.
    /// </summary>
    /// <remarks>
    /// Optional, and must stay so. Every service created before this existed has none, and a
    /// business should not be stopped from editing an old service just to answer a question that
    /// was never asked when it was made.
    ///
    /// Always belongs to <see cref="ServiceCategoryId"/>; the commands that set it check that
    /// rather than trust it, since the two arrive from the client as separate fields.
    /// </remarks>
    public Guid? ServiceSubCategoryId { get; set; }

    public ServiceSubCategory? ServiceSubCategory { get; set; }

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
