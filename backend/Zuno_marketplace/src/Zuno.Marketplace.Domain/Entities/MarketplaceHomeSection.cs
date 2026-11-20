using Zuno.Marketplace.Domain.Enums;

namespace Zuno.Marketplace.Domain.Entities;

/// <summary>
/// One section of the customer's Marketplace home: its heading, where its posts come from, how it
/// is drawn and how many it shows. The home is these rows in order, so a section is added, moved,
/// renamed or switched off by changing a row. An empty section is left out.
/// </summary>
public class MarketplaceHomeSection
{
    /// <summary>A short stable name, e.g. <c>best_sellers</c>, used by the app's keys and tests.</summary>
    public string Code { get; set; } = string.Empty;

    /// <summary>The heading; empty for none (the banner).</summary>
    public string Title { get; set; } = string.Empty;

    public MarketplaceHomeSource Source { get; set; }

    public MarketplaceHomeLayout Layout { get; set; }

    /// <summary>How many posts it shows (a grid of 8 is four rows of two). A feed's page size.</summary>
    public short ItemCount { get; set; }

    /// <summary>The source's setting: a discount's lowest percentage ("30"), or an audience's values ("Men,Unisex").</summary>
    public string? Parameter { get; set; }

    public short DisplayOrder { get; set; }

    public bool IsActive { get; set; } = true;
}
