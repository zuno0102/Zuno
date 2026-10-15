namespace Zuno.Application.Modules.Catalog.DTOs;

public class DistrictDto
{
    public Guid Id { get; set; }

    public string Name { get; set; } = string.Empty;

    public Guid StateId { get; set; }

    public string StateName { get; set; } = string.Empty;

    /// <summary>
    /// Where the district is, or null for one outside the curated states.
    /// </summary>
    /// <remarks>
    /// Sent so the app can suggest places as somebody types without a network call per keystroke. The
    /// free geocoder behind place search does no prefix matching at all — "Thiruvan" returns nothing —
    /// so this list, already cached client side, is what makes as-you-type possible.
    /// </remarks>
    public decimal? CentreLatitude { get; set; }

    public decimal? CentreLongitude { get; set; }
}
