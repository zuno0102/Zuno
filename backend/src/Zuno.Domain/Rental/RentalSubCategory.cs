using Zuno.Domain.Common;

namespace Zuno.Domain.Rental;

/// <summary>A narrower kind within a <see cref="RentalCategory"/> — Tools &amp; machines › Cutting machine.</summary>
public class RentalSubCategory : BaseEntity
{
    public Guid RentalCategoryId { get; set; }

    public RentalCategory RentalCategory { get; set; } = null!;

    public string Name { get; set; } = string.Empty;

    public string Slug { get; set; } = string.Empty;

    public short DisplayOrder { get; set; }

    public bool IsActive { get; set; } = true;
}
