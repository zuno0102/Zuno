using MediatR;
using Zuno.Application.Modules.Booking.DTOs;

namespace Zuno.Application.Modules.Booking.Commands.AcceptBookingTerms;

/// <summary>
/// Takes up the other side's offer, which is what confirms the order.
/// </summary>
/// <remarks>
/// The agreed crew size and price land on the booking in the same save that confirms it, so there
/// is never a moment where an order is confirmed at terms nobody recorded.
/// </remarks>
public class AcceptBookingTermsCommand : IRequest<BookingDto>
{
    public Guid BookingId { get; set; }

    /// <summary>
    /// Which offer is being accepted.
    /// </summary>
    /// <remarks>
    /// Named rather than "whatever is open" so that a counter landing at the same moment cannot
    /// be accepted by mistake. The handler can then say the offer was replaced instead of quietly
    /// binding someone to terms they never saw.
    /// </remarks>
    public Guid ProposalId { get; set; }
}
