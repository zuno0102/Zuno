using Zuno.Marketplace.Domain.Common;
using Zuno.Marketplace.Domain.Enums;

namespace Zuno.Marketplace.Domain.Entities;

/// <summary>
/// One thing a business puts up: a listing (car, plot, saree, bulk produce), a food offer or an
/// advertisement. The owner is the signed-in user's id from the shared login; no link to Service rows.
/// </summary>
public class MarketplacePost : BaseEntity
{
    public Guid OwnerUserId { get; set; }

    public Guid CategoryId { get; set; }

    public MarketplaceCategory Category { get; set; } = null!;

    /// <summary>The sub-category, e.g. Sarees. Required while the category has any; null on older posts.</summary>
    public Guid? SubCategoryId { get; set; }

    public MarketplaceSubCategory? SubCategory { get; set; }

    /// <summary>Copied from the category when saved, so a later change of the category never changes the rules a post was checked by.</summary>
    public MarketplacePostKind Kind { get; set; }

    public MarketplacePostStatus Status { get; set; } = MarketplacePostStatus.Active;

    public string Title { get; set; } = string.Empty;

    public string? Description { get; set; }

    /// <summary>The asking price; for a food offer the offer price. Null on an advertisement without one.</summary>
    public decimal? Price { get; set; }

    /// <summary>What the price is for, e.g. "kg" or "plate". Null means the whole thing.</summary>
    public string? PriceUnit { get; set; }

    public MarketplaceTradeType TradeType { get; set; } = MarketplaceTradeType.Retail;

    /// <summary>Wholesale only: the smallest order, in <see cref="PriceUnit"/>.</summary>
    public int? MinOrderQuantity { get; set; }

    /// <summary>
    /// How many are for sale (kg of bananas); for a food offer, the portions; for a new item in a
    /// category that keeps stock, the stock left — 0 is out of stock.
    /// </summary>
    public int? Quantity { get; set; }

    /// <summary>New or Used, in a category that keeps stock; null elsewhere.</summary>
    public MarketplaceItemCondition? Condition { get; set; }

    /// <summary>Food offer only: the usual price, shown struck through.</summary>
    public decimal? OriginalPrice { get; set; }

    /// <summary>When a food offer or advertisement starts. Null on a listing.</summary>
    public DateTimeOffset? StartsAt { get; set; }

    /// <summary>When a food offer or advertisement ends; after this an Active post shows as Expired.</summary>
    public DateTimeOffset? EndsAt { get; set; }

    /// <summary>Advertisement only: the number to call about it.</summary>
    public string? ContactPhone { get; set; }

    public Guid DistrictId { get; set; }

    public RefDistrict District { get; set; } = null!;

    /// <summary>Town or locality, e.g. "Marthandam".</summary>
    public string? Area { get; set; }

    /// <summary>Where the shop is, so "near you" can be worked out. Both or neither.</summary>
    public double? Latitude { get; set; }

    public double? Longitude { get; set; }

    /// <summary>The category's own details (year, km, fuel …), keyed by the field's key.</summary>
    public List<MarketplacePostAttribute> Attributes { get; set; } = [];

    /// <summary>
    /// Details the business adds itself where the category's list has none — "Leather type: Genuine",
    /// keyed by the business's own name for it. Stored with the post as JSON.
    /// </summary>
    public List<MarketplacePostAttribute> CustomDetails { get; set; } = [];

    /// <summary>
    /// Where a product ships: all of India; else the whole of <see cref="DeliveryStateId"/>; else
    /// only its <see cref="DeliveryDistrictIds"/>.
    /// </summary>
    public bool DeliversEverywhere { get; set; } = true;

    /// <summary>The state it ships in when not everywhere.</summary>
    public Guid? DeliveryStateId { get; set; }

    /// <summary>Districts of <see cref="DeliveryStateId"/> it ships to; empty is the whole state.</summary>
    public List<Guid> DeliveryDistrictIds { get; set; } = [];

    /// <summary>
    /// A new product's colours and sizes, each with its own stock (and price, when it differs). With
    /// any, <see cref="Quantity"/> is their stock added up.
    /// </summary>
    public ICollection<MarketplacePostVariant> Variants { get; set; } = new List<MarketplacePostVariant>();

    public ICollection<MarketplacePostMedia> Media { get; set; } = new List<MarketplacePostMedia>();

    /// <summary>True when the post's time has passed — it then neither shows to customers nor uses a plan slot.</summary>
    public bool HasEnded(DateTimeOffset now) => EndsAt is { } end && end <= now;

    /// <summary>
    /// The detail key apps before 1.15 kept New / Used under. Still read from older apps (an APK not
    /// yet updated, a browser tab left open), which send it as a detail instead of the condition.
    /// </summary>
    public const string LegacyConditionKey = "condition";

    /// <summary>A new item with a stock count: the business keeps the count up to date.</summary>
    public bool KeepsStock => Condition == MarketplaceItemCondition.New;

    /// <summary>A new item whose stock has run out: listed, but not shown to customers.</summary>
    public bool IsOutOfStock => KeepsStock && Quantity is null or <= 0;

    /// <summary>Closed or Sold: nothing about the post changes any more.</summary>
    public bool IsFinal => Status is MarketplacePostStatus.Closed or MarketplacePostStatus.Sold;

    /// <summary>What the business and customers see: Active turns Expired once its end has passed.</summary>
    public MarketplacePostStatus ShownStatus(DateTimeOffset now) =>
        Status == MarketplacePostStatus.Active && HasEnded(now) ? MarketplacePostStatus.Expired : Status;
}

/// <summary>One category field's value on a post. Stored inside the post's row as JSON.</summary>
public class MarketplacePostAttribute
{
    public string Key { get; set; } = string.Empty;

    public string Value { get; set; } = string.Empty;
}

/// <summary>
/// One colour / size of a new product — "Red · M" — with its own stock, and its own price when it
/// differs from the post's. Its own row, so an order can name exactly what was bought.
/// </summary>
public class MarketplacePostVariant : BaseEntity
{
    public Guid PostId { get; set; }

    public MarketplacePost Post { get; set; } = null!;

    public string? Colour { get; set; }

    public string? Size { get; set; }

    /// <summary>Null sells at the post's price.</summary>
    public decimal? Price { get; set; }

    /// <summary>How many are left; 0 is out of stock.</summary>
    public int Stock { get; set; }

    public short SortOrder { get; set; }

    /// <summary>"Red · M", "Red", "M".</summary>
    public string Name => string.Join(" · ", new[] { Colour, Size }.Where(p => !string.IsNullOrWhiteSpace(p)));
}

/// <summary>A photo of a post. Slot 0 is the cover, and an advertisement's banner.</summary>
public class MarketplacePostMedia : BaseEntity
{
    public Guid PostId { get; set; }

    public MarketplacePost Post { get; set; } = null!;

    public string Url { get; set; } = string.Empty;

    public short SortOrder { get; set; }
}
