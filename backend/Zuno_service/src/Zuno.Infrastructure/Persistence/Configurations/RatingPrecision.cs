namespace Zuno.Infrastructure.Persistence.Configurations;

/// <summary>Column size for a running total of stars, shared by every table that keeps one.</summary>
internal static class RatingPrecision
{
    /// <summary>Digits in all: room for billions of five-star ratings.</summary>
    public const int SumDigits = 14;

    /// <summary>Places after the point. Stars are whole, but the Rent API may send a fractional total.</summary>
    public const int SumScale = 2;
}
