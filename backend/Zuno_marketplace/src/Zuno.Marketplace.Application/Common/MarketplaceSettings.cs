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

    /// <summary>How long the category list and options are cached; they change rarely.</summary>
    [Range(0, 86_400)]
    public int CategoryCacheSeconds { get; set; } = 600;
}
