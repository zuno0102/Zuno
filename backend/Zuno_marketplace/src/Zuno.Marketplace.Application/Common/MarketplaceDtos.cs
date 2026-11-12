namespace Zuno.Marketplace.Application.Common;

/// <summary>A post as its business sees it. Enums travel as their names.</summary>
public class MarketplacePostDto
{
    public Guid Id { get; set; }

    public Guid CategoryId { get; set; }

    public string CategoryName { get; set; } = string.Empty;

    public string? CategoryIconName { get; set; }

    public Guid? SubCategoryId { get; set; }

    public string? SubCategoryName { get; set; }

    public string Kind { get; set; } = string.Empty;

    /// <summary>As shown: an Active post whose end has passed comes back <c>Expired</c>.</summary>
    public string Status { get; set; } = string.Empty;

    public string Title { get; set; } = string.Empty;

    public string? Description { get; set; }

    public decimal? Price { get; set; }

    public string? PriceUnit { get; set; }

    public string TradeType { get; set; } = string.Empty;

    public int? MinOrderQuantity { get; set; }

    public int? Quantity { get; set; }

    public decimal? OriginalPrice { get; set; }

    public DateTimeOffset? StartsAt { get; set; }

    public DateTimeOffset? EndsAt { get; set; }

    public string? ContactPhone { get; set; }

    public Guid DistrictId { get; set; }

    public string DistrictName { get; set; } = string.Empty;

    public Guid StateId { get; set; }

    public string StateName { get; set; } = string.Empty;

    public string? Area { get; set; }

    public double? Latitude { get; set; }

    public double? Longitude { get; set; }

    /// <summary>The category's own details, by field key.</summary>
    public Dictionary<string, string> Attributes { get; set; } = [];

    public List<MarketplacePostMediaDto> Media { get; set; } = [];

    /// <summary>The moves the business may make now, in menu order (from the transitions table).</summary>
    public List<MarketplacePostActionDto> Actions { get; set; } = [];

    public DateTimeOffset CreatedDate { get; set; }
}

public class MarketplacePostMediaDto
{
    public string Url { get; set; } = string.Empty;

    public short SortOrder { get; set; }
}

public class MarketplacePostActionDto
{
    public string ToStatus { get; set; } = string.Empty;

    public string Name { get; set; } = string.Empty;

    public bool NeedsConfirm { get; set; }
}

/// <summary>One page of a business's posts.</summary>
public class MarketplacePostPageDto
{
    public List<MarketplacePostDto> Items { get; set; } = [];

    public int Page { get; set; }

    public int PageSize { get; set; }

    public int TotalCount { get; set; }
}

/// <summary>The business home screen's Marketplace tiles and the plan banner.</summary>
public class MarketplaceSummaryDto
{
    public int Active { get; set; }

    public int Paused { get; set; }

    public int Expired { get; set; }

    public int Closed { get; set; }

    /// <summary>The same counts per main category the business has posted in.</summary>
    public List<MarketplaceCategoryCountDto> Categories { get; set; } = [];

    public MarketplacePlanDto Plan { get; set; } = new();
}

/// <summary>A main category's posts by shown status, for the Orders › Marketplace chips.</summary>
public class MarketplaceCategoryCountDto
{
    public Guid CategoryId { get; set; }

    public int Active { get; set; }

    public int Paused { get; set; }

    public int Expired { get; set; }

    public int Closed { get; set; }
}

/// <summary>The business's plan and how much of it is used.</summary>
public class MarketplacePlanDto
{
    public string Code { get; set; } = string.Empty;

    public string Name { get; set; } = string.Empty;

    public decimal Price { get; set; }

    public int MaxActivePosts { get; set; }

    public int UsedActivePosts { get; set; }

    /// <summary>Null for the default plan, which never ends.</summary>
    public DateTimeOffset? EndsAt { get; set; }

    public bool CanAddActivePost => UsedActivePosts < MaxActivePosts;
}

public class MarketplaceCategoryDto
{
    public Guid Id { get; set; }

    public string Name { get; set; } = string.Empty;

    /// <summary>The few letters the category squares show; the name when there is none.</summary>
    public string ShortName { get; set; } = string.Empty;

    public string? Description { get; set; }

    public string Slug { get; set; } = string.Empty;

    public string? IconName { get; set; }

    public string Kind { get; set; } = string.Empty;

    /// <summary><c>RetailOnly</c>, <c>WholesaleOnly</c> or <c>Either</c>.</summary>
    public string TradeMode { get; set; } = string.Empty;

    public short DisplayOrder { get; set; }

    public bool IsActive { get; set; }

    public List<MarketplaceSubCategoryDto> SubCategories { get; set; } = [];

    public List<MarketplaceCategoryFieldDto> Fields { get; set; } = [];
}

public class MarketplaceSubCategoryDto
{
    public Guid Id { get; set; }

    public string Name { get; set; } = string.Empty;

    public string Slug { get; set; } = string.Empty;

    public string? IconName { get; set; }

    public short DisplayOrder { get; set; }

    public bool IsActive { get; set; }
}

public class MarketplaceCategoryFieldDto
{
    public Guid Id { get; set; }

    /// <summary>The one sub-category it is asked for; null for the whole category.</summary>
    public Guid? SubCategoryId { get; set; }

    public string Key { get; set; } = string.Empty;

    public string Label { get; set; } = string.Empty;

    public string FieldType { get; set; } = string.Empty;

    public List<string> Options { get; set; } = [];

    public string? Unit { get; set; }

    public bool IsRequired { get; set; }

    public short DisplayOrder { get; set; }

    public bool IsActive { get; set; }
}

/// <summary>The reference lists and limits the app draws the Marketplace screens from.</summary>
public class MarketplaceOptionsDto
{
    public List<MarketplaceOptionDto> Kinds { get; set; } = [];

    /// <summary>How a category may sell, named for the super admin.</summary>
    public List<MarketplaceOptionDto> TradeModes { get; set; } = [];

    public List<MarketplaceOptionDto> Statuses { get; set; } = [];

    public int ImageSlots { get; set; }

    public int MaxFoodOfferHours { get; set; }

    public int MaxAdDays { get; set; }

    public decimal MaxPrice { get; set; }

    public int MaxQuantity { get; set; }
}

public class MarketplaceOptionDto
{
    public string Code { get; set; } = string.Empty;

    public string Name { get; set; } = string.Empty;

    /// <summary>The app's status colour; null on a list without colours.</summary>
    public string? Tone { get; set; }

    /// <summary>A line under the name; null on a list without one.</summary>
    public string? Detail { get; set; }
}
