using Zuno.Domain.Common;
using Zuno.Domain.Enums;

namespace Zuno.Domain.Entities;

/// <summary>
/// A plan a business can be on: which areas it opens and what it costs. Every price, length and name
/// is set by the Super Admin; a bought plan keeps a copy of its terms, so an edit never rewrites it.
/// The default row is the free Basic plan, which allows <see cref="MaxLiveListings"/> live listings in
/// total across all areas.
/// </summary>
public class SubscriptionPlan : BaseEntity
{
    /// <summary>A stable name for code and tests, e.g. <c>all3-monthly</c>.</summary>
    public string Code { get; set; } = string.Empty;

    public string Name { get; set; } = string.Empty;

    public bool IncludesService { get; set; }

    public bool IncludesRent { get; set; }

    public bool IncludesMarketplace { get; set; }

    /// <summary>The most live listings in total; null for no limit inside the plan's areas. Basic: 1.</summary>
    public int? MaxLiveListings { get; set; }

    public decimal Price { get; set; }

    /// <summary>How long one purchase runs; null for the Basic plan, which never ends.</summary>
    public int? DurationDays { get; set; }

    public PlanPeriod Period { get; set; }

    /// <summary>The free Basic plan every business is on without a paid one. Exactly one row.</summary>
    public bool IsDefault { get; set; }

    /// <summary>On sale. A plan taken off sale keeps running for whoever already paid.</summary>
    public bool IsActive { get; set; } = true;

    public short SortOrder { get; set; }

    public bool Includes(ListingArea area) => area switch
    {
        ListingArea.Service => IncludesService,
        ListingArea.Rent => IncludesRent,
        ListingArea.Marketplace => IncludesMarketplace,
        _ => false,
    };
}
