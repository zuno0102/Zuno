using MediatR;
using Zuno.Application.Common.Interfaces;
using Zuno.Application.Modules.Booking.DTOs;
using Zuno.Domain.Enums;
using Zuno.Domain.Exceptions;

namespace Zuno.Application.Modules.Booking.Commands.AcceptBookingTerms;

public class AcceptBookingTermsCommandHandler(
    ICurrentUserService currentUserService,
    IDateTimeProvider dateTimeProvider,
    IBookingRepository bookingRepository,
    IApplicationDbContext dbContext) : IRequestHandler<AcceptBookingTermsCommand, BookingDto>
{
    public async Task<BookingDto> Handle(
        AcceptBookingTermsCommand request,
        CancellationToken cancellationToken)
    {
        var userId = currentUserService.UserId
            ?? throw new UnauthorizedAccessException("User is not authenticated.");

        var booking = await bookingRepository.GetByIdAsync(request.BookingId, cancellationToken)
            ?? throw new EntityNotFoundException(nameof(Domain.Entities.Booking), request.BookingId);

        var isCustomer = booking.CustomerProfile.UserId == userId;
        var isBusiness = booking.BusinessOwnerProfile.UserId == userId;

        if (!isCustomer && !isBusiness)
        {
            throw new UnauthorizedAccessException("This booking does not belong to you.");
        }

        if (booking.BookingStatus != BookingStatus.Pending)
        {
            throw new DomainException(
                booking.BookingStatus is BookingStatus.Cancelled
                    ? "This order was cancelled, so there is nothing left to agree."
                    : "This order is already confirmed.");
        }

        var proposal = booking.AgreementProposals.FirstOrDefault(p => p.Id == request.ProposalId)
            ?? throw new EntityNotFoundException("BookingAgreementProposal", request.ProposalId);

        // Named by id on purpose, so a counter that landed in the meantime is reported rather
        // than silently applied in place of the one being looked at.
        if (!proposal.IsOpen)
        {
            throw new DomainException(
                "That offer has been replaced. Look at the latest one before accepting.");
        }

        var mySide = isBusiness ? BookingPartyRole.Business : BookingPartyRole.Customer;

        // The rule the whole thing rests on. Without it a business accepts its own ₹48,000 and
        // the customer is bound to a figure they never agreed to.
        if (proposal.ProposedByRole == mySide)
        {
            throw new DomainException(
                "This is your own offer. It is for the other side to accept or counter.");
        }

        var now = dateTimeProvider.UtcNow;

        proposal.ProposalStatus = BookingProposalStatus.Accepted;
        proposal.RespondedAt = now;
        proposal.RespondedByUserId = userId;

        // The agreed figures land on the columns everything downstream already reads — the
        // dashboard's revenue, the wage rollup, the three detail screens. Nothing else changes.
        booking.RequiredWorkerCount = proposal.WorkerCount;
        booking.PriceQuoted = proposal.Price;
        booking.BookingStatus = BookingStatus.Confirmed;

        await dbContext.SaveChangesAsync(cancellationToken);

        return booking.ToDto(includeCrew: isBusiness);
    }
}
