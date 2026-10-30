using Zuno.Rent.Domain.Common;

namespace Zuno.Rent.Domain.Entities;

/// <summary>A kind of thing rented out, e.g. "Furniture &amp; seating". Table-driven: rows, not code.</summary>
public class RentalCategory : BaseEntity
{
    public string Name { get; set; } = string.Empty;

    public string Slug { get; set; } = string.Empty;

    /// <summary>Which icon the app draws for this category.</summary>
    public string? IconName { get; set; }

    public short DisplayOrder { get; set; }

    public bool IsActive { get; set; } = true;

    public ICollection<RentalSubCategory> SubCategories { get; set; } = new List<RentalSubCategory>();
}

/// <summary>A narrower kind within a category, e.g. "Cutting machine" under "Tools &amp; machines".</summary>
public class RentalSubCategory : BaseEntity
{
    public Guid RentalCategoryId { get; set; }

    public RentalCategory RentalCategory { get; set; } = null!;

    public string Name { get; set; } = string.Empty;

    public string Slug { get; set; } = string.Empty;

    public short DisplayOrder { get; set; }

    public bool IsActive { get; set; } = true;
}
