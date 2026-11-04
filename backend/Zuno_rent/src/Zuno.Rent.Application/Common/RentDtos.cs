namespace Zuno.Rent.Application.Common;

/// <summary>A rent item as the business sees it on its Rent tab.</summary>
public class RentalItemDto
{
    public Guid Id { get; set; }

    public Guid RentalCategoryId { get; set; }

    public string RentalCategoryName { get; set; } = string.Empty;

    public Guid? RentalSubCategoryId { get; set; }

    public string? RentalSubCategoryName { get; set; }

    public string Name { get; set; } = string.Empty;

    public string? Description { get; set; }

    /// <summary><c>Hourly</c>, <c>Daily</c> or <c>Fixed</c>.</summary>
    public string PriceType { get; set; } = string.Empty;

    public decimal Price { get; set; }

    /// <summary>How many of this item the business has to rent out.</summary>
    public int QuantityOwned { get; set; }

    /// <summary><c>None</c>, <c>PerOrder</c> or <c>PerPiece</c>.</summary>
    public string AdvanceType { get; set; } = string.Empty;

    /// <summary>Null when no advance is asked.</summary>
    public decimal? AdvanceAmount { get; set; }

    /// <summary>Off while the item cannot be rented, e.g. under repair.</summary>
    public bool IsAvailable { get; set; }

    public List<RentalItemMediaDto> Media { get; set; } = [];

    public List<RentalItemDistrictDto> Districts { get; set; } = [];

    /// <summary>In display order.</summary>
    public List<RentalItemQuestionDto> Questions { get; set; } = [];

    /// <summary>The cancellation charge by time left, nearest the start first. Empty is free cancellation.</summary>
    public List<RentalCancelStepDto> CancelSteps { get; set; } = [];

    /// <summary><c>Day</c>, or <c>Hour</c> for an hourly item: what the steps count.</summary>
    public string CancelUnit { get; set; } = string.Empty;

    /// <summary><c>ByTimeLeft</c> (the steps) or <c>PerRentalDay</c>.</summary>
    public string CancelChargeType { get; set; } = string.Empty;

    /// <summary>For <c>PerRentalDay</c>: the percent for each day (or hour) rented.</summary>
    public decimal? CancelPercentPerDay { get; set; }
}

/// <summary>"<see cref="UnitsBefore"/>+ days before → <see cref="Percent"/>% of the order".</summary>
public class RentalCancelStepDto
{
    public int UnitsBefore { get; set; }

    public decimal Percent { get; set; }
}

public class RentalItemQuestionDto
{
    public Guid Id { get; set; }

    public string Prompt { get; set; } = string.Empty;

    public bool IsRequired { get; set; }
}

/// <summary>One rate type the form offers, as the app draws it.</summary>
public class RentalPriceTypeDto
{
    /// <summary><c>Daily</c>, <c>Fixed</c> or <c>Hourly</c> — what an item save sends back.</summary>
    public string Code { get; set; } = string.Empty;

    public string Name { get; set; } = string.Empty;

    public string Detail { get; set; } = string.Empty;

    public string UnitSuffix { get; set; } = string.Empty;
}

public class RentalItemMediaDto
{
    public Guid Id { get; set; }

    /// <summary><c>Image</c> or <c>Video</c>.</summary>
    public string MediaType { get; set; } = string.Empty;

    public string Url { get; set; } = string.Empty;

    public short SortOrder { get; set; }
}

public class RentalItemDistrictDto
{
    public Guid Id { get; set; }

    public string Name { get; set; } = string.Empty;

    public Guid StateId { get; set; }

    public string StateName { get; set; } = string.Empty;
}

/// <summary>One page of a business's rent items.</summary>
public class RentalItemPageDto
{
    public List<RentalItemDto> Items { get; set; } = [];

    public int Page { get; set; }

    public int PageSize { get; set; }

    public int TotalCount { get; set; }
}

public class RentalCategoryDto
{
    public Guid Id { get; set; }

    public string Name { get; set; } = string.Empty;

    public string Slug { get; set; } = string.Empty;

    public string? IconName { get; set; }

    /// <summary>The most a business may keep on a cancellation, in percent — set per category by the super admin.</summary>
    public decimal MaxCancelPercent { get; set; }

    public List<RentalSubCategoryDto> SubCategories { get; set; } = [];
}

public class RentalSubCategoryDto
{
    public Guid Id { get; set; }

    public string Name { get; set; } = string.Empty;

    public string Slug { get; set; } = string.Empty;

    /// <summary>The limit for items under this sub-category: its own, or its category's.</summary>
    public decimal MaxCancelPercent { get; set; }
}
