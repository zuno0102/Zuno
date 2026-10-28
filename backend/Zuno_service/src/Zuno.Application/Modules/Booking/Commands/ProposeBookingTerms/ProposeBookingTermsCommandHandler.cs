using MediatR;
using Zuno.Application.Common.Interfaces;
using Zuno.Application.Modules.Booking.DTOs;
using Zuno.Application.Modules.Booking.Events;
using Zuno.Application.Modules.Notifications.Common;
using Zuno.Domain.Entities;
using Zuno.Domain.Enums;
using Zuno.Domain.Exceptions;

namespace Zuno.Application.Modules.Booking.Commands.ProposeBookingTerms;

public class ProposeBookingTermsCommandHandler(
    ICurrentUserService currentUserService,
    IDateTimeProvider dateTimeProvider,
    IBookingRepository bookingRepository,
    IApplicationDbContext dbContext,
    IPublisher publisher) : IRequestHandler<ProposeBookingTermsCommand, BookingDto>
{
    public async Task<BookingDto> Handle(
        ProposeBookingTermsCommand request,
        CancellationToken cancellationToken)
    {
        var userId = currentUserService.UserId
            ?? throw new UnauthorizedAccessException("User is not authenticated.");

        var booking = await bookingRepository.GetByIdAsync(request.BookingId, cancellationToken)
            ?? throw new EntityNotFoundException(nameof(Domain.Entities.Booking), request.BookingId);

        var isCustomer = booking.CustomerProfile.UserId == userId;
        var isBusiness = booking.BusinessOwnerProfile.UserId == userId;

        // A worker assigned to this order is a legitimate viewer of it, so "can see it" is not
        // the test. Only the two parties to the agreement may offer terms for it.
        if (!isCustomer && !isBusiness)
        {
            throw new UnauthorizedAccessException("This booking does not belong to you.");
        }

        // The whole negotiation lives inside the window where the business may still walk away.
        // Once an order is confirmed the customer has stopped looking elsewhere, and reopening
        // the price afterwards is the same broken promise as cancelling it.
        if (booking.BookingStatus != BookingStatus.Pending)
        {
            throw new DomainException(
                booking.BookingStatus is BookingStatus.Cancelled
                    ? "This order was cancelled, so there is nothing left to agree."
                    : "This order is already confirmed. Its crew and price were settled when it "
                      + "was accepted.");
        }

        var open = booking.AgreementProposals.FirstOrDefault(p => p.IsOpen);
        var mySide = isBusiness ? BookingPartyRole.Business : BookingPartyRole.Customer;

        // Replacing your own open offer would let one side talk to itself and, worse, quietly
        // move a number the other side is in the middle of reading.
        if (open is not null && open.ProposedByRole == mySide)
        {
            throw new DomainException(
                "Your offer is still on the table. Wait for their answer, or cancel the order.");
        }

        if (request.WorkerCount < booking.ActiveCrewCount)
        {
            throw new DomainException(
                $"This order already has {booking.ActiveCrewCount} worker(s) on it — the crew "
                + "cannot be agreed lower than that.");
        }

        var now = dateTimeProvider.UtcNow;

        // Superseded, not deleted: the history of who offered what is the point of keeping rows.
        if (open is not null)
        {
            open.ProposalStatus = BookingProposalStatus.Superseded;
            open.RespondedAt = now;
            open.RespondedByUserId = userId;
        }

        var proposal = new BookingAgreementProposal
        {
            BookingId = booking.Id,
            ProposedByRole = mySide,
            ProposedByUserId = userId,
            WorkerCount = request.WorkerCount,
            Price = request.Price,
            Message = request.Message?.Trim(),
            ProposalStatus = BookingProposalStatus.Open,
        };

        // Added on the DbSet rather than only through the navigation collection: BaseEntity fills
        // the key in before EF sees the object, so a child found by navigation fixup on a tracked
        // parent is taken for an existing row and emitted as an UPDATE that matches nothing.
        dbContext.BookingAgreementProposals.Add(proposal);
        booking.AgreementProposals.Add(proposal);

        await dbContext.SaveChangesAsync(cancellationToken);

        // The other side, whichever that is. An offer nobody is told about is an order that sits
        // open until somebody happens to look at it, which is exactly the hunting this replaces.
        await publisher.Publish(
            new BookingTermsProposedEvent(
                booking.Id,
                isBusiness ? booking.CustomerProfile.UserId : booking.BusinessOwnerProfile.UserId,
                isBusiness
                    ? booking.BusinessOwnerProfile.BusinessName
                    : NotificationText.Person(
                        booking.CustomerProfile.User.FirstName,
                        booking.CustomerProfile.User.LastName),
                proposal.Price,
                proposal.WorkerCount),
            cancellationToken);

        return booking.ToDto(includeCrew: isBusiness);
    }
}
