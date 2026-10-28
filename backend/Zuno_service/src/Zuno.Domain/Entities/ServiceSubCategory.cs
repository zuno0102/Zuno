using Zuno.Domain.Common;

namespace Zuno.Domain.Entities;

/// <summary>
/// A narrower kind of work inside a main category — "Kitchen cleaning" under "Cleaning".
/// </summary>
/// <remarks>
/// Sub-categories are what an item on a service is actually tagged with. The main category is
/// never picked twice: an item inherits it from its parent service, and a sub-category can only
/// be chosen from the ones belonging to that category.
/// </remarks>
public class ServiceSubCategory : BaseEntity
{
    public Guid ServiceCategoryId { get; set; }

    public ServiceCategory ServiceCategory { get; set; } = null!;

    public string Name { get; set; } = string.Empty;

    public string Slug { get; set; } = string.Empty;

    public short DisplayOrder { get; set; }

    public bool IsActive { get; set; } = true;
}
