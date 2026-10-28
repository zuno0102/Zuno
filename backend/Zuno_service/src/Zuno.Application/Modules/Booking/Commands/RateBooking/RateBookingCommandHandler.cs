using MediatR;
using Zuno.Application.Common.Interfaces;
using Zuno.Application.Modules.Booking.DTOs;
using Zuno.Application.Modules.Booking.Events;
using Zuno.Domain.Entities;
using Zuno.Domain.Enums;
using Zuno.Domain.Exceptions;

namespace Zuno.Application.Modules.Booking.Commands.RateBooking;

public class RateBookingCommandHandler(
    ICurrentUserService currentUserService,
    IBookingRepository bookingRepository,
    IBusinessReputationService reputationService,
    IApplicationDbContext dbContext,
    IPublisher publisher) : IRequestHandler<RateBookingCommand, RatingDto>
{
    public async Task<RatingDto> Handle(RateBookingCommand request, CancellationToken cancellationToken)
    {
        var userId = currentUserService.UserId
            ?? throw new UnauthorizedAccessException("User is not authenticated.");

        var booking = await bookingRepository.GetByIdAsync(request.BookingId, cancellationToken)
            ?? throw new EntityNotFoundException(nameof(Domain.Entities.Booking), request.BookingId);

        if (booking.CustomerProfile.UserId != userId)
        {
            throw new UnauthorizedAccessException("This booking does not belong to you.");
        }

        if (booking.BookingStatus != BookingStatus.Completed)
        {
            throw new DomainException("Only completed bookings can be rated.");
        }

        if (booking.Rating is not null)
        {
            throw new DomainException("This booking has already been rated.");
        }

        var rating = new Rating
        {
            BookingId = booking.Id,
            CustomerProfileId = booking.CustomerProfileId,
            BusinessOwnerProfileId = booking.BusinessOwnerProfileId,
            Score = request.Score,
            Comment = request.Comment,
        };

        dbContext.Ratings.Add(rating);
        await dbContext.SaveChangesAsync(cancellationToken);

        // The stars a customer leaves have to reach the business's standing, and nothing else was
        // doing it.
        //
        // Every other handler that changes what a business is worth recalculates here — finishing
        // work, settling a payout, answering a payment — but rating did not, so a review sat in the
        // ratings table and showed nowhere. A business with one five-star job read as unrated on
        // its profile and in search until it happened to finish some *other* job, which is the
        // moment an unrelated recalculation ran and swept it up.
        //
        // After the save, never before: the average is counted out of the database and cannot see
        // a rating that is still only in the change tracker.
        await reputationService.RecalculateAndSaveAsync(
            booking.BusinessOwnerProfileId, cancellationToken);

        await publisher.Publish(
            new BookingRatedEvent(
                booking.Id,
                booking.BusinessOwnerProfile.UserId,
                rating.Score),
            cancellationToken);

        return new RatingDto
        {
            Score = rating.Score,
            Comment = rating.Comment,
            CreatedDate = rating.CreatedDate,
        };
    }
}
