namespace Zuno.Application.Modules.BusinessPlans;

/// <summary>A plan on sale, as the business sees it.</summary>
public class PlanOfferDto
{
    public Guid Id { get; set; }

    public string Code { get; set; } = string.Empty;

    public string Name { get; set; } = string.Empty;

    /// <summary><c>Monthly</c> or <c>Annual</c>.</summary>
    public string Period { get; set; } = string.Empty;

    public decimal Price { get; set; }

    public int DurationDays { get; set; }

    public bool IncludesService { get; set; }

    public bool IncludesRent { get; set; }

    public bool IncludesMarketplace { get; set; }
}

/// <summary>One area: how many listings are live there, and whether one more may go up.</summary>
public class AreaUsageDto
{
    /// <summary><c>Service</c>, <c>Rent</c> or <c>Marketplace</c>.</summary>
    public string Area { get; set; } = string.Empty;

    /// <summary>Null when the area could not be reached just now.</summary>
    public int? LiveCount { get; set; }

    public bool CanAdd { get; set; }

    /// <summary>Why not, in words for the business; null when it can add.</summary>
    public string? Reason { get; set; }
}

/// <summary>The business's plan: what it is on, what it uses, and what it can buy.</summary>
public class BusinessPlanDto
{
    /// <summary>The running paid plan's name, or the Basic plan's.</summary>
    public string PlanName { get; set; } = string.Empty;

    public bool IsBasic { get; set; }

    public DateTimeOffset? EndsAt { get; set; }

    public bool IncludesService { get; set; }

    public bool IncludesRent { get; set; }

    public bool IncludesMarketplace { get; set; }

    /// <summary>How many live listings the Basic plan allows in total.</summary>
    public int BasicLimit { get; set; }

    public List<AreaUsageDto> Areas { get; set; } = [];

    /// <summary>Listings the end of a plan paused; they come back on renewal.</summary>
    public int PausedCount { get; set; }

    public List<PlanOfferDto> Plans { get; set; } = [];
}

/// <summary>A purchase started: the Razorpay order to pay, or nothing to collect.</summary>
public class PlanPaymentDto
{
    public Guid SubscriptionId { get; set; }

    public string PlanName { get; set; } = string.Empty;

    public decimal Amount { get; set; }

    public int DurationDays { get; set; }

    public string? ProviderOrderId { get; set; }

    public string? RazorpayKeyId { get; set; }

    /// <summary>True when no payment window is needed (a free plan, or collection simulated in Development).</summary>
    public bool NothingToCollect { get; set; }
}

/// <summary>The answer to Rent or Marketplace asking before a listing goes live.</summary>
public class ListingAllowanceDto
{
    public bool Allowed { get; set; }

    public string? Reason { get; set; }
}
