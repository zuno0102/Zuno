using Zuno.Domain.Entities;
using Zuno.Domain.Enums;

namespace Zuno.Application.Modules.Booking.DTOs;

/// <summary>One offer on an order, as either side sees it.</summary>
public class BookingTermsProposalDto
{
    public Guid Id { get; set; }

    /// <summary>"Customer" or "Business" — which side made this offer.</summary>
    public string ProposedByRole { get; set; } = string.Empty;

    public int WorkerCount { get; set; }

    public decimal Price { get; set; }

    public string? Message { get; set; }

    /// <summary>"Open", "Accepted" or "Superseded".</summary>
    public string ProposalStatus { get; set; } = string.Empty;

    public DateTimeOffset CreatedDate { get; set; }

    public DateTimeOffset? RespondedAt { get; set; }
}

public static class BookingTermsMappingExtensions
{
    public static BookingTermsProposalDto ToDto(this BookingAgreementProposal proposal) => new()
    {
        Id = proposal.Id,
        ProposedByRole = proposal.ProposedByRole.ToString(),
        WorkerCount = proposal.WorkerCount,
        Price = proposal.Price,
        Message = proposal.Message,
        ProposalStatus = proposal.ProposalStatus.ToString(),
        CreatedDate = proposal.CreatedDate,
        RespondedAt = proposal.RespondedAt,
    };

    /// <summary>The rounds in the order they happened.</summary>
    /// <remarks>
    /// There is no round number stored: the rounds <em>are</em> these rows in the order they were
    /// created, which is one fewer thing that can disagree with itself.
    /// </remarks>
    public static List<BookingTermsProposalDto> ToProposalDtos(
        this IEnumerable<BookingAgreementProposal> proposals) =>
        [.. proposals.OrderBy(p => p.CreatedDate).Select(p => p.ToDto())];

    /// <summary>
    /// Who owes the other a reply, worked out from the offers rather than stored.
    /// </summary>
    /// <remarks>
    /// Derived for the same reason <c>CrewStatus</c> is: a stored copy is one more thing that can
    /// drift from the rows it summarises. It also means no new <c>BookingStatus</c> value, so
    /// every existing switch over the order's status keeps working untouched — and an older build
    /// in someone's hand cannot meet a status it has no label for.
    ///
    /// Named from neither side's point of view. The app turns these into "Waiting for you" and
    /// "Waiting for them" depending on who is looking.
    /// </remarks>
    public static string AgreementStatusOf(this Domain.Entities.Booking booking)
    {
        var proposals = booking.AgreementProposals;

        if (proposals.Count == 0)
        {
            return "NotRequired";
        }

        if (proposals.Any(p => p.ProposalStatus == BookingProposalStatus.Accepted))
        {
            return "Agreed";
        }

        var open = proposals.FirstOrDefault(p => p.IsOpen);

        if (open is null)
        {
            // Offers were made and none is live: the order was cancelled out from under them.
            return "Closed";
        }

        return open.ProposedByRole == BookingPartyRole.Business
            ? "AwaitingCustomer"
            : "AwaitingBusiness";
    }
}
