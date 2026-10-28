using System.ComponentModel.DataAnnotations;

namespace Zuno.Application.Rental.Common;

/// <summary>
/// The Rent module's limits, from configuration (section <c>Rental</c>) rather than code, so they
/// can change without a release.
/// </summary>
public class RentalSettings
{
    public const string SectionName = "Rental";

    /// <summary>The most of one item a business can list — generous for chairs, refusing typos.</summary>
    [Range(1, 1_000_000)]
    public int MaxQuantityOwned { get; set; } = 100_000;

    /// <summary>The highest rate for one item, so a stray zero is caught before a customer sees it.</summary>
    [Range(1, 100_000_000)]
    public decimal MaxPrice { get; set; } = 10_000_000m;

    /// <summary>The most districts one item can be offered in.</summary>
    [Range(1, 1_000)]
    public int MaxDistricts { get; set; } = 200;

    /// <summary>Page size when the app asks for none.</summary>
    [Range(1, 500)]
    public int DefaultPageSize { get; set; } = 50;

    /// <summary>The largest page the app may ask for.</summary>
    [Range(1, 500)]
    public int MaxPageSize { get; set; } = 100;

    /// <summary>How long the category list is cached; it changes rarely.</summary>
    [Range(0, 86_400)]
    public int CategoryCacheSeconds { get; set; } = 600;
}
