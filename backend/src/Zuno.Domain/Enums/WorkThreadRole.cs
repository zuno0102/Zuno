namespace Zuno.Domain.Enums;

/// <summary>Which side of a business–worker conversation someone is on.</summary>
/// <remarks>
/// Separate from <see cref="BookingPartyRole"/> on purpose. That one names the two sides of an order
/// (customer and business); this names the two sides of a working relationship. Customers and
/// workers never speak to each other directly — the business is the middle man — so no role ever
/// appears in both.
/// </remarks>
public enum WorkThreadRole : short
{
    Business = 1,

    Worker = 2,
}
