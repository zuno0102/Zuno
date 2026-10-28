namespace Zuno.Domain.Enums;

/// <summary>Which side of an order someone is on.</summary>
/// <remarks>
/// Recorded on an offer so the rule "only the other side may accept it" can be enforced without
/// re-deriving who made it from user ids every time.
/// </remarks>
public enum BookingPartyRole : short
{
    Customer = 1,

    Business = 2,
}
