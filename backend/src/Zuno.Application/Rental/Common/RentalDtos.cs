namespace Zuno.Application.Rental.Common;

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

    /// <summary>Off while the item cannot be rented, e.g. under repair.</summary>
    public bool IsAvailable { get; set; }

    public List<RentalItemMediaDto> Media { get; set; } = [];

    public List<RentalItemDistrictDto> Districts { get; set; } = [];
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

    public List<RentalSubCategoryDto> SubCategories { get; set; } = [];
}

public class RentalSubCategoryDto
{
    public Guid Id { get; set; }

    public string Name { get; set; } = string.Empty;

    public string Slug { get; set; } = string.Empty;
}
