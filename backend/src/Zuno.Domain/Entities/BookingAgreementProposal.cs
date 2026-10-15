using Zuno.Domain.Common;
using Zuno.Domain.Enums;

namespace Zuno.Domain.Entities;

/// <summary>
/// One offer on an order: how many people, for how much.
/// </summary>
/// <remarks>
/// The conversation the app never used to have. A business needs 20 for a wedding, the customer
/// says 18 is enough — before this existed that happened on the phone and the order still carried
/// whatever the service template said.
///
/// Every round is its own row, so the history reads back in full. Rounds are not numbered: they
/// are the rows in <c>CreatedDate</c> order, which cannot disagree with themselves.
///
/// Two rules hold this together, and both are enforced in the handlers:
/// only the party who did <em>not</em> make an open offer may accept or counter it, and offers
/// exist only while the order is still Pending — the window in which the business may also still
/// walk away.
/// </remarks>
public class BookingAgreementProposal : BaseEntity
{
    public Guid BookingId { get; set; }

    public Booking Booking { get; set; } = null!;

    /// <summary>Which side made this offer.</summary>
    public BookingPartyRole ProposedByRole { get; set; }

    public Guid ProposedByUserId { get; set; }

    /// <summary>The crew size being offered.</summary>
    public int WorkerCount { get; set; }

    /// <summary>What the order would cost at that crew size.</summary>
    /// <remarks>
    /// An absolute figure, not a formula. For a per-person service the app works it out as
    /// rate × count and shows the arithmetic, but what is stored and agreed is the amount itself —
    /// so a later change to the service's rate cannot move a price both sides already shook on.
    /// </remarks>
    public decimal Price { get; set; }

    /// <summary>Why, in the proposer's words. "18 can't cover 300 guests."</summary>
    public string? Message { get; set; }

    public BookingProposalStatus ProposalStatus { get; set; } = BookingProposalStatus.Open;

    public DateTimeOffset? RespondedAt { get; set; }

    public Guid? RespondedByUserId { get; set; }

    public bool IsOpen => ProposalStatus == BookingProposalStatus.Open;
}
