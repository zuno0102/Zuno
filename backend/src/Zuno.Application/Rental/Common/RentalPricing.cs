using Zuno.Domain.Enums;
using Zuno.Domain.Rental;

namespace Zuno.Application.Rental.Common;

/// <summary>Reads the rate type the app sends — <c>Hourly</c>, <c>Daily</c> or <c>Fixed</c>.</summary>
internal static class RentalPricing
{
    /// <summary>The price type, or null when it is not one a rent item can be charged by.</summary>
    public static PriceType? Parse(string? value) =>
        Enum.TryParse<PriceType>(value, ignoreCase: true, out var parsed)
        && Enum.IsDefined(parsed)
        && RentalItem.AllowedPriceTypes.Contains(parsed)
            ? parsed
            : null;

    public static string AllowedList => string.Join(", ", RentalItem.AllowedPriceTypes);
}
