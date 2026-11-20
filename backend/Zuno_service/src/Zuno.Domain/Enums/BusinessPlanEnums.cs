namespace Zuno.Domain.Enums;

// Stored values: append-only, never renumber.

/// <summary>The three areas a business lists in. Each lives in its own API; Service owns the plan over all three.</summary>
public enum ListingArea : short
{
    Service = 1,

    Rent = 2,

    Marketplace = 3,
}

/// <summary>How a plan is billed.</summary>
public enum PlanPeriod : short
{
    /// <summary>The free Basic plan: never billed, never ends.</summary>
    Free = 0,

    Monthly = 1,

    Annual = 2,
}

/// <summary>Where a bought plan stands.</summary>
public enum SubscriptionStatus : short
{
    /// <summary>Started, not paid yet. Gives nothing.</summary>
    AwaitingPayment = 1,

    /// <summary>Paid. Runs from <c>StartsAt</c> to <c>EndsAt</c>.</summary>
    Active = 2,

    /// <summary>Its end has passed and the listings beyond Basic were paused.</summary>
    Ended = 3,
}
