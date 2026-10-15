namespace Zuno.Application.Modules.Customer.DTOs;

/// <summary>
/// One service as it appears in a customer's browse list.
/// </summary>
/// <remarks>
/// Flattened across businesses on purpose. People shop for "catering", not for a particular
/// caterer they have never heard of — so the list leads with the service and carries just
/// enough of the business to judge and to navigate to.
/// </remarks>
public class ServiceListingDto
{
    public Guid Id { get; set; }

    public string Name { get; set; } = string.Empty;

    public string? Description { get; set; }

    public string ServiceCategoryName { get; set; } = string.Empty;

    public Guid ServiceCategoryId { get; set; }

    public decimal Price { get; set; }

    public string PriceType { get; set; } = string.Empty;

    /// <summary>First image, for the card. Null when the business has uploaded none.</summary>
    public string? ImageUrl { get; set; }

    // ---- The business behind it ----------------------------------------------------------

    public Guid BusinessOwnerProfileId { get; set; }

    public string BusinessName { get; set; } = string.Empty;

    public string? BusinessLogoUrl { get; set; }

    public string? City { get; set; }

    /// <summary>Their standing, 1-5. Lets a card show who is worth trusting.</summary>
    public int Level { get; set; } = 1;

    /// <summary>The name for that standing — computed server-side so every client agrees.</summary>
    public string LevelName { get; set; } = string.Empty;

    public decimal? RatingAverage { get; set; }

    public int ReviewCount { get; set; }
}
