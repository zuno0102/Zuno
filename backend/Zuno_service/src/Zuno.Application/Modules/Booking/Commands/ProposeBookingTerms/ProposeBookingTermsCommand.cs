using MediatR;
using Zuno.Application.Modules.Booking.DTOs;

namespace Zuno.Application.Modules.Booking.Commands.ProposeBookingTerms;

/// <summary>
/// Puts an offer on an order: this many people, for this much.
/// </summary>
/// <remarks>
/// One command for both sides, like <c>CancelBookingCommand</c>. The business makes the first
/// offer after reading what the customer said about the job; the customer counters. Whoever did
/// not make the open offer may replace it, as many times as it takes.
/// </remarks>
public class ProposeBookingTermsCommand : IRequest<BookingDto>
{
    public Guid BookingId { get; set; }

    public int WorkerCount { get; set; }

    /// <summary>The whole order's price at that crew size, not a rate.</summary>
    public decimal Price { get; set; }

    /// <summary>Why, in the proposer's own words. Optional.</summary>
    public string? Message { get; set; }
}
