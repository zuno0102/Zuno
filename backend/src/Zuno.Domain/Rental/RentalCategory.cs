using Zuno.Domain.Common;

namespace Zuno.Domain.Rental;

/// <summary>
/// A kind of thing a business rents out — Furniture &amp; seating, Tools &amp; machines. Data, not
/// code: rows are seeded and can be added or renamed without a release.
/// </summary>
/// <remarks>
/// Part of the Rent module. Kept apart from the service catalogue (<c>ServiceCategory</c>), so the
/// two can grow independently and a change to one never reaches the other.
/// </remarks>
public class RentalCategory : BaseEntity
{
    public string Name { get; set; } = string.Empty;

    public string Slug { get; set; } = string.Empty;

    /// <summary>A short key the app maps to one of the icons it ships with.</summary>
    public string? IconName { get; set; }

    public short DisplayOrder { get; set; }

    public bool IsActive { get; set; } = true;

    public ICollection<RentalSubCategory> SubCategories { get; set; } = new List<RentalSubCategory>();
}
