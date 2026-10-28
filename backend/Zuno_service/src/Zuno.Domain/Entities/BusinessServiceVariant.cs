using Zuno.Domain.Common;
using Zuno.Domain.Enums;

namespace Zuno.Domain.Entities;

/// <summary>
/// A named, individually-priced, individually-bookable sub-item under a service — e.g. a
/// "Band Set" service might have variants "Band", "Chenda Melam", "Panjabi Band". Inherits
/// its parent service's category and target districts; only pricing/media are its own.
/// </summary>
public class BusinessServiceVariant : BaseEntity
{
    public Guid BusinessServiceId { get; set; }

    public BusinessService BusinessService { get; set; } = null!;

    /// <summary>
    /// The kind of work this item is, inside the parent service's category. Optional only
    /// because items created before sub-categories existed have none.
    /// </summary>
    public Guid? ServiceSubCategoryId { get; set; }

    public ServiceSubCategory? ServiceSubCategory { get; set; }

    public string Name { get; set; } = string.Empty;

    public string? Description { get; set; }

    public PriceType PriceType { get; set; } = PriceType.Fixed;

    public decimal Price { get; set; }

    public short? EstimatedDurationMinutes { get; set; }

    public bool IsActive { get; set; } = true;

    public ICollection<BusinessServiceMedia> Media { get; set; } = new List<BusinessServiceMedia>();
}
