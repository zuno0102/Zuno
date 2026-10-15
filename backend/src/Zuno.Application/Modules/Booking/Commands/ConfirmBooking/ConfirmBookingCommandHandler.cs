using MediatR;
using Zuno.Application.Common.Interfaces;
using Zuno.Application.Modules.Booking.DTOs;
using Zuno.Application.Modules.Booking.Events;
using Zuno.Domain.Entities;
using Zuno.Domain.Enums;
using Zuno.Domain.Exceptions;

namespace Zuno.Application.Modules.Booking.Commands.ConfirmBooking;

public class ConfirmBookingCommandHandler(
    ICurrentUserService currentUserService,
    IBusinessOwnerProfileRepository businessOwnerProfileRepository,
    IBookingRepository bookingRepository,
    IApplicationDbContext dbContext,
    IPublisher publisher) : IRequestHandler<ConfirmBookingCommand, BookingDto>
{
    public async Task<BookingDto> Handle(ConfirmBookingCommand request, CancellationToken cancellationToken)
    {
        var userId = currentUserService.UserId
            ?? throw new UnauthorizedAccessException("User is not authenticated.");

        var businessProfile = await businessOwnerProfileRepository.GetByUserIdAsync(userId, cancellationToken)
            ?? throw new EntityNotFoundException(nameof(BusinessOwnerProfile), userId);

        var booking = await bookingRepository.GetByIdAsync(request.BookingId, cancellationToken)
            ?? throw new EntityNotFoundException(nameof(Domain.Entities.Booking), request.BookingId);

        if (booking.BusinessOwnerProfileId != businessProfile.Id)
        {
            throw new UnauthorizedAccessException("This booking does not belong to your business.");
        }

        if (booking.BookingStatus != BookingStatus.Pending)
        {
            throw new DomainException("This booking has already been confirmed or is no longer pending.");
        }

        // "Accept as booked" means accepting the order exactly as it stands. With an offer still
        // open it would mean something else entirely: a business that has just offered ₹48,000
        // could press this and lock in the ₹40,000 the service happens to list, and a customer's
        // open counter could be confirmed at the terms they had just turned down. One rule covers
        // both, because either direction of open offer makes this button ambiguous.
        if (booking.AgreementProposals.Any(p => p.IsOpen))
        {
            throw new DomainException(
                "There is an open offer on this order — accept it or counter it first.");
        }

        booking.BookingStatus = BookingStatus.Confirmed;

        await dbContext.SaveChangesAsync(cancellationToken);

        // After the save, so a notification can never announce a confirmation that did not commit.
        await publisher.Publish(
            new BookingConfirmedEvent(
                booking.Id,
                booking.CustomerProfile.UserId,
                booking.BusinessOwnerProfile.BusinessName,
                booking.BusinessServiceVariant?.Name ?? booking.BusinessService.Name,
                booking.ScheduledDate),
            cancellationToken);

        return booking.ToDto();
    }
}
