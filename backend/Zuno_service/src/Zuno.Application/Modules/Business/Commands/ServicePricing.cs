using Zuno.Domain.Enums;

namespace Zuno.Application.Modules.Business.Commands;

/// <summary>
/// Reading a price type off the wire, where it arrives as a name rather than a number.
/// </summary>
public static class ServicePricing
{
    /// <summary>
    /// Whether this price is a rate per worker, so the crew size is agreed per booking.
    /// </summary>
    /// <remarks>
    /// Returns false for anything unparseable rather than throwing. The price type has its own
    /// validation rule; this one only decides which crew-size rule applies, and a bad price type
    /// should fail with "PriceType must be one of…" rather than with a crew-size complaint.
    /// </remarks>
    public static bool IsPerPerson(string? priceType) =>
        Enum.TryParse<PriceType>(priceType, ignoreCase: true, out var parsed)
        && parsed == PriceType.PerPerson;
}
