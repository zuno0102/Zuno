using System.ComponentModel.DataAnnotations;

namespace Zuno.Marketplace.Application.Common;

/// <summary>
/// The Marketplace limits, from configuration (section <c>Marketplace</c>) rather than code, so they
/// can change without a release. Per-plan limits live in the <c>marketplace_plans</c> table.
/// </summary>
public class MarketplaceSettings
{
    public const string SectionName = "Marketplace";

    /// <summary>The highest price, so a stray zero is caught before a customer sees it (a house can be crores).</summary>
    [Range(1, 10_000_000_000)]
    public decimal MaxPrice { get; set; } = 1_000_000_000m;

    /// <summary>The most of one thing a post can offer — tonnes of produce in kg, or plates of food.</summary>
    [Range(1, 100_000_000)]
    public int MaxQuantity { get; set; } = 1_000_000;

    /// <summary>Photo slots per post. Slot 0 is the cover and an advertisement's banner.</summary>
    [Range(1, 10)]
    public int ImageSlots { get; set; } = 5;

    /// <summary>Photo slots per colour / size — the saree in that colour.</summary>
    [Range(1, 10)]
    public int VariantImageSlots { get; set; } = 3;

    /// <summary>
    /// What a B2B post can be sold in — "Sold in" on the form: kg for onions, piece for taps. Set in
    /// appsettings only: configuration adds a list to a default given here instead of replacing it,
    /// so a default would show every unit twice. Empty, the app uses its own list.
    /// </summary>
    public string[] WholesaleUnits { get; set; } = [];

    /// <summary>The longest a food offer may run — "last-time" food is gone the same day.</summary>
    [Range(1, 168)]
    public int MaxFoodOfferHours { get; set; } = 24;

    /// <summary>The longest one advertisement may run.</summary>
    [Range(1, 366)]
    public int MaxAdDays { get; set; } = 60;

    /// <summary>How far ahead a food offer or advertisement may be set to start.</summary>
    [Range(0, 366)]
    public int MaxStartDaysAhead { get; set; } = 30;

    [Range(1, 500)]
    public int DefaultPageSize { get; set; } = 30;

    [Range(1, 500)]
    public int MaxPageSize { get; set; } = 100;

    /// <summary>How long an online order holds its stock while the customer pays; unpaid by then, it is let go.</summary>
    [Range(1, 1440)]
    public int PaymentHoldMinutes { get; set; } = 15;

    /// <summary>A delivered order with no review closes by itself this many days after delivery.</summary>
    [Range(1, 90)]
    public int AutoCloseDays { get; set; } = 10;

    /// <summary>
    /// How long the home's shared rankings (newest, best sellers, discounts…) are kept before being
    /// worked out again; 0 works them out every time. Each card is still checked to be on show.
    /// </summary>
    [Range(0, 3600)]
    public int HomeCacheSeconds { get; set; } = 120;

    /// <summary>How many days back the home's "Trending" section counts orders.</summary>
    [Range(1, 90)]
    public int TrendingDays { get; set; } = 7;

    /// <summary>How many recent posts the home's "near you" sections are sorted from by distance.</summary>
    [Range(10, 1000)]
    public int HomeNearbyPoolSize { get; set; } = 100;

    /// <summary>The most posts one customer may keep on their wishlist.</summary>
    [Range(1, 5000)]
    public int MaxFavourites { get; set; } = 500;

    /// <summary>The longest search words a customer may type.</summary>
    [Range(10, 200)]
    public int MaxSearchLength { get; set; } = 60;

    /// <summary>How long the category list and options are cached; they change rarely.</summary>
    [Range(0, 86_400)]
    public int CategoryCacheSeconds { get; set; } = 600;
}
