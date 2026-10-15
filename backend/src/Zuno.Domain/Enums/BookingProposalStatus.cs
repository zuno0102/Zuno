namespace Zuno.Domain.Enums;

/// <summary>Where one offer on an order stands.</summary>
public enum BookingProposalStatus : short
{
    /// <summary>On the table, waiting for the other side. Only one per order at a time.</summary>
    Open = 1,

    /// <summary>Taken up. Accepting an offer is what confirms the order.</summary>
    Accepted = 2,

    /// <summary>Replaced by a counter, or closed because the order was.</summary>
    Superseded = 3,
}
