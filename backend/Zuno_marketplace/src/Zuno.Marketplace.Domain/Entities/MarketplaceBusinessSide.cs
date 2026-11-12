using Zuno.Marketplace.Domain.Common;
using Zuno.Marketplace.Domain.Enums;

namespace Zuno.Marketplace.Domain.Entities;

/// <summary>
/// What Marketplace knows of a business, copied from its Service profile: the name customers see and
/// whether it is verified. Customers only ever see posts of verified businesses.
/// </summary>
public class MarketplaceBusiness
{
    public Guid OwnerUserId { get; set; }

    public string Name { get; set; } = string.Empty;

    public string? LogoUrl { get; set; }

    public bool IsVerified { get; set; }

    public DateTimeOffset RefreshedAt { get; set; }
}

/// <summary>
/// A plan a business posts under: how many posts may be live at once, and what it costs. The plan
/// marked default is everyone's until they take another. Rows, so prices and limits change without a release.
/// </summary>
public class MarketplacePlan : BaseEntity
{
    public string Code { get; set; } = string.Empty;

    public string Name { get; set; } = string.Empty;

    public decimal Price { get; set; }

    /// <summary>How many Active, not-yet-ended posts a business on this plan may have at once.</summary>
    public int MaxActivePosts { get; set; }

    /// <summary>How long a taken plan lasts. Null for the default plan, which never ends.</summary>
    public int? DurationDays { get; set; }

    /// <summary>The plan every business is on until it takes another. Exactly one row.</summary>
    public bool IsDefault { get; set; }

    public bool IsActive { get; set; } = true;

    public short DisplayOrder { get; set; }
}

/// <summary>
/// A plan a business has taken, and until when. None current means the default plan. Paid plans will
/// add rows here when subscriptions are set up.
/// </summary>
public class MarketplaceBusinessPlan : BaseEntity
{
    public Guid OwnerUserId { get; set; }

    public Guid PlanId { get; set; }

    public MarketplacePlan Plan { get; set; } = null!;

    public DateTimeOffset StartsAt { get; set; }

    /// <summary>Null runs until replaced.</summary>
    public DateTimeOffset? EndsAt { get; set; }
}

/// <summary>How a trade mode is named on the super admin's screen — "Wholesale only (B2B)". Table-driven, keyed by the enum.</summary>
public class MarketplaceTradeModeOption
{
    public MarketplaceTradeMode Code { get; set; }

    public string Name { get; set; } = string.Empty;

    /// <summary>The line under the name, e.g. "Bulk to businesses: price per unit and a smallest order".</summary>
    public string Detail { get; set; } = string.Empty;

    public short DisplayOrder { get; set; }
}

/// <summary>How a post kind is named and ordered. Table-driven, keyed by the enum.</summary>
public class MarketplacePostKindOption
{
    public MarketplacePostKind Code { get; set; }

    public string Name { get; set; } = string.Empty;

    public short DisplayOrder { get; set; }

    public bool IsActive { get; set; } = true;
}

/// <summary>How a post status is named and coloured.</summary>
public class MarketplacePostStatusOption
{
    public MarketplacePostStatus Code { get; set; }

    public string Name { get; set; } = string.Empty;

    /// <summary>The app's status colour: <c>success</c>, <c>progress</c>, <c>waiting</c> or <c>danger</c>.</summary>
    public string Tone { get; set; } = "waiting";

    public short DisplayOrder { get; set; }
}

/// <summary>
/// A move the business may make on its post, e.g. Active → Paused is "Pause". The post's menu is
/// these rows, so a new step needs no release.
/// </summary>
public class MarketplacePostTransition
{
    public MarketplacePostStatus FromStatus { get; set; }

    public MarketplacePostStatus ToStatus { get; set; }

    /// <summary>The menu label, e.g. "Pause".</summary>
    public string ActionName { get; set; } = string.Empty;

    /// <summary>Ask "are you sure?" first — for a move that cannot be undone.</summary>
    public bool NeedsConfirm { get; set; }

    /// <summary>Offered only on posts in this condition — "Mark as sold" on used items; null for every post.</summary>
    public MarketplaceItemCondition? Condition { get; set; }

    public short DisplayOrder { get; set; }

    /// <summary>Whether this move is offered on <paramref name="post"/>, from its stored status and condition.</summary>
    public bool AppliesTo(MarketplacePost post) =>
        FromStatus == post.Status && (Condition is null || Condition == post.Condition);
}

/// <summary>How New and Used are named, with the line under each on the post form. Keyed by the enum.</summary>
public class MarketplaceItemConditionOption
{
    public MarketplaceItemCondition Code { get; set; }

    public string Name { get; set; } = string.Empty;

    /// <summary>E.g. "Brand new — keep a stock count".</summary>
    public string Detail { get; set; } = string.Empty;

    public short DisplayOrder { get; set; }
}
