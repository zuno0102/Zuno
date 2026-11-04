using System.ComponentModel.DataAnnotations;

namespace Zuno.Rent.Application.Common;

/// <summary>
/// The Rent limits, from configuration (section <c>Rent</c>) rather than code, so they can change
/// without a release.
/// </summary>
public class RentSettings
{
    public const string SectionName = "Rent";

    /// <summary>The most of one item a business can list — generous for chairs, refusing typos.</summary>
    [Range(1, 1_000_000)]
    public int MaxQuantityOwned { get; set; } = 100_000;

    /// <summary>The highest rate for one item, so a stray zero is caught before a customer sees it.</summary>
    [Range(1, 100_000_000)]
    public decimal MaxPrice { get; set; } = 10_000_000m;

    /// <summary>The most districts one item can be offered in.</summary>
    [Range(1, 1_000)]
    public int MaxDistricts { get; set; } = 200;

    /// <summary>The most questions one item can ask — enough for any rental, few enough to fill on a phone.</summary>
    [Range(0, 50)]
    public int MaxQuestions { get; set; } = 15;

    /// <summary>Photo slots per item.</summary>
    [Range(1, 10)]
    public int ImageSlots { get; set; } = 3;

    [Range(1, 500)]
    public int DefaultPageSize { get; set; } = 50;

    [Range(1, 500)]
    public int MaxPageSize { get; set; } = 100;

    /// <summary>How many items the customer's Rent home shuffles its sections from.</summary>
    [Range(10, 2_000)]
    public int HomePoolSize { get; set; } = 200;

    /// <summary>The most results one customer search returns.</summary>
    [Range(1, 200)]
    public int SearchTake { get; set; } = 40;

    /// <summary>Featured items in the Rent home's banner.</summary>
    [Range(1, 20)]
    public int BannerCount { get; set; } = 5;

    /// <summary>
    /// How long an app booking that asks an advance holds the pieces while the customer pays; unpaid
    /// by then, the booking is let go.
    /// </summary>
    [Range(1, 1_440)]
    public int AdvanceHoldMinutes { get; set; } = 15;

    /// <summary>The most cancellation steps one item can have — enough for "a week, 3 days, a day, same day".</summary>
    [Range(1, 20)]
    public int MaxCancelSteps { get; set; } = 5;

    /// <summary>
    /// How far ahead a cancellation step can start, in days (times 24 for an hourly item). Bookings
    /// reach a year ahead, so a step further out than that could never apply.
    /// </summary>
    [Range(1, 3_660)]
    public int MaxCancelDaysBefore { get; set; } = 366;

    /// <summary>
    /// The platform's ceiling on any cancellation charge, whatever a category's own limit says — a
    /// mistyped category row can never let a business keep more than this.
    /// </summary>
    [Range(0, 100)]
    public decimal CancelPercentCeiling { get; set; } = 20m;

    /// <summary>How long the category and rate-type lists are cached; they change rarely.</summary>
    [Range(0, 86_400)]
    public int CategoryCacheSeconds { get; set; } = 600;
}
