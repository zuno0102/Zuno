namespace Zuno.Application.Modules.Customer.DTOs;

public class BusinessSummaryDto
{
    public Guid Id { get; set; }

    public string BusinessName { get; set; } = string.Empty;

    public string? Description { get; set; }

    public string? LogoUrl { get; set; }

    public string? City { get; set; }

    public string? State { get; set; }

    public List<string> ServiceCategoryNames { get; set; } = [];

    // ---- Standing ------------------------------------------------------------------------
    //
    // Already maintained on the profile by BusinessReputationService, but until now it never
    // reached a customer — so a business that pays its crew properly looked identical to one
    // that does not. These are what make the badge on a search result mean anything.

    /// 1-5. See <c>BusinessLevel</c>.
    public int Level { get; set; } = 1;

    /// <summary>The name for that standing — computed server-side so every client agrees.</summary>
    public string LevelName { get; set; } = string.Empty;

    /// Null until anyone has rated them.
    public decimal? RatingAverage { get; set; }

    public int ReviewCount { get; set; }

    /// Jobs finished <em>and</em> paid for in full.
    public int CompletedJobCount { get; set; }

    /// The cheapest thing they offer, for the "from" line on a card. Null when unpriced.
    public decimal? StartingPrice { get; set; }
}
