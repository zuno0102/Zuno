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

    /// <summary>
    /// The most a business may charge, as a percent of the order, when a customer cancels an item of
    /// this category. Set by the platform, not the business: a business setting 5% on plastic chairs
    /// that allow 2% is refused.
    /// </summary>
    public decimal MaxCancelPercent { get; set; }

    public ICollection<RentalSubCategory> SubCategories { get; set; } = new List<RentalSubCategory>();

    /// <summary>The limit for an item filed under this category and, if any, one of its sub-categories.</summary>
    public decimal CancelLimitFor(RentalSubCategory? subCategory) =>
        subCategory?.MaxCancelPercent ?? MaxCancelPercent;
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

    /// <summary>
    /// A tighter (or looser) cancellation limit than the category's for this kind of item — plastic
    /// chairs 2% under furniture's 5%. Null takes the category's.
    /// </summary>
    public decimal? MaxCancelPercent { get; set; }
}
