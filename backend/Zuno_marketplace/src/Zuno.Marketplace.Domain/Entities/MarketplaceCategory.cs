using Zuno.Marketplace.Domain.Common;
using Zuno.Marketplace.Domain.Enums;

namespace Zuno.Marketplace.Domain.Entities;

/// <summary>
/// A main kind of thing posted, e.g. "Products" or "Nearby food", holding sub-categories ("Sarees",
/// "Biryani &amp; meals"). Added and changed by the super admin: rows, not code. The kind decides the
/// rules a post in it follows, the trade mode whether it sells retail, wholesale or either.
/// </summary>
public class MarketplaceCategory : BaseEntity
{
    public string Name { get; set; } = string.Empty;

    /// <summary>The few letters the category squares have room for, e.g. "B2B". Null shows the name.</summary>
    public string? ShortName { get; set; }

    /// <summary>What goes in it, shown in the post form's picker, e.g. "Sarees, shirts, toys".</summary>
    public string? Description { get; set; }

    public string Slug { get; set; } = string.Empty;

    /// <summary>Which icon the app draws for this category.</summary>
    public string? IconName { get; set; }

    public MarketplacePostKind Kind { get; set; } = MarketplacePostKind.Listing;

    /// <summary>Whether posts here sell one at a time, in bulk to businesses (B2B), or either.</summary>
    public MarketplaceTradeMode TradeMode { get; set; } = MarketplaceTradeMode.RetailOnly;

    /// <summary>
    /// Posts here say New or Used: a new item keeps a stock count (out of stock at 0), a used one is a
    /// single piece marked Sold when it goes. On for Products.
    /// </summary>
    public bool TracksStock { get; set; }

    public short DisplayOrder { get; set; }

    /// <summary>Off hides the category from the post form and its posts from customers.</summary>
    public bool IsActive { get; set; } = true;

    public ICollection<MarketplaceSubCategory> SubCategories { get; set; } = new List<MarketplaceSubCategory>();

    public ICollection<MarketplaceCategoryField> Fields { get; set; } = new List<MarketplaceCategoryField>();
}

/// <summary>A narrower kind within a main category, e.g. "Sarees" under Products or "Fruits" under B2B.</summary>
public class MarketplaceSubCategory : BaseEntity
{
    public Guid CategoryId { get; set; }

    public MarketplaceCategory Category { get; set; } = null!;

    public string Name { get; set; } = string.Empty;

    public string Slug { get; set; } = string.Empty;

    public string? IconName { get; set; }

    public short DisplayOrder { get; set; }

    /// <summary>Off hides it from the post form and its posts from customers.</summary>
    public bool IsActive { get; set; } = true;
}

/// <summary>
/// A detail a post asks for, e.g. "KM driven" for Products › Vehicles or "Food type" for all of Nearby
/// food. The form is drawn from these rows, so a new detail needs no release.
/// </summary>
public class MarketplaceCategoryField : BaseEntity
{
    public Guid CategoryId { get; set; }

    public MarketplaceCategory Category { get; set; } = null!;

    /// <summary>The one sub-category this detail is asked for; null asks it everywhere in the category.</summary>
    public Guid? SubCategoryId { get; set; }

    public MarketplaceSubCategory? SubCategory { get; set; }

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

    /// <summary>Whether a post filed under <paramref name="subCategoryId"/> is asked this detail.</summary>
    public bool AppliesTo(Guid? subCategoryId) =>
        IsActive && !IsDeleted && (SubCategoryId is null || SubCategoryId == subCategoryId);
}
