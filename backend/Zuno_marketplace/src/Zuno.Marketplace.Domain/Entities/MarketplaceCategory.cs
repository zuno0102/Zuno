using Zuno.Marketplace.Domain.Common;
using Zuno.Marketplace.Domain.Enums;

namespace Zuno.Marketplace.Domain.Entities;

/// <summary>
/// A kind of thing posted, e.g. "Vehicles" or "Food offers". Added and changed by the super admin:
/// rows, not code. The kind decides the rules a post in it follows.
/// </summary>
public class MarketplaceCategory : BaseEntity
{
    public string Name { get; set; } = string.Empty;

    public string Slug { get; set; } = string.Empty;

    /// <summary>Which icon the app draws for this category.</summary>
    public string? IconName { get; set; }

    public MarketplacePostKind Kind { get; set; } = MarketplacePostKind.Listing;

    /// <summary>Whether posts here may sell in bulk to businesses (B2B), e.g. farm produce.</summary>
    public bool AllowsWholesale { get; set; }

    public short DisplayOrder { get; set; }

    /// <summary>Off hides the category from the post form and its posts from customers.</summary>
    public bool IsActive { get; set; } = true;

    public ICollection<MarketplaceCategoryField> Fields { get; set; } = new List<MarketplaceCategoryField>();
}

/// <summary>
/// A detail a post in the category asks for, e.g. "KM driven" for Vehicles or "Area (cents)" for
/// Property. The form is drawn from these rows, so a new detail needs no release.
/// </summary>
public class MarketplaceCategoryField : BaseEntity
{
    public Guid CategoryId { get; set; }

    public MarketplaceCategory Category { get; set; } = null!;

    /// <summary>Stable name the value is saved under, e.g. <c>km_driven</c>. Never shown.</summary>
    public string Key { get; set; } = string.Empty;

    public string Label { get; set; } = string.Empty;

    public MarketplaceFieldType FieldType { get; set; } = MarketplaceFieldType.Text;

    /// <summary>The choices of a <see cref="MarketplaceFieldType.Select"/> field; empty otherwise.</summary>
    public List<string> Options { get; set; } = [];

    /// <summary>Written after a number, e.g. "km".</summary>
    public string? Unit { get; set; }

    public bool IsRequired { get; set; }

    public short DisplayOrder { get; set; }

    public bool IsActive { get; set; } = true;
}
