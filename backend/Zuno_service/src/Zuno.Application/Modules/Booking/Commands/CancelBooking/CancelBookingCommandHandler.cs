using MediatR;
using Microsoft.EntityFrameworkCore;
using Zuno.Application.Common.Interfaces;
using Zuno.Application.Modules.Booking.DTOs;
using Zuno.Application.Modules.Booking.Events;
using Zuno.Application.Modules.Notifications.Common;
using Zuno.Domain.Enums;
using Zuno.Domain.Exceptions;

namespace Zuno.Application.Modules.Booking.Commands.CancelBooking;

public class CancelBookingCommandHandler(
    ICurrentUserService currentUserService,
    IDateTimeProvider dateTimeProvider,
    IBookingRepository bookingRepository,
    IApplicationDbContext dbContext,
    IPublisher publisher) : IRequestHandler<CancelBookingCommand, BookingDto>
{
    public async Task<BookingDto> Handle(CancelBookingCommand request, CancellationToken cancellationToken)
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

        if (booking.BookingStatus is BookingStatus.Completed or BookingStatus.Cancelled)
        {
            throw new DomainException("This booking can no longer be cancelled.");
        }

        // A business may turn an order down before it takes it on, and not after. Confirming is
        // the promise — once it is made the customer stops looking elsewhere and starts planning
        // around it, and a business dropping the job from a button is not a promise at all.
        // A customer may still cancel their own order at any point; it is theirs to call off.
        if (isBusiness && booking.BookingStatus != BookingStatus.Pending)
        {
            throw new DomainException(
                "You have already accepted this order, so it cannot be declined here. "
                + "Speak to the customer — cancelling is theirs to do.");
        }

        booking.BookingStatus = BookingStatus.Cancelled;
        booking.CancelledAt = dateTimeProvider.UtcNow;
        booking.CancellationReason = request.Reason;

        // Stop any hiring raised for this order from still advertising a job that no longer
        // exists. Workers who already accepted keep their agreed wage and payment record — they
        // took the job in good faith, and the business calling off the order does not undo that.
        var openPosts = await dbContext.HiringPosts
            .Where(p => p.BookingId == booking.Id)
            .Where(p => p.HiringPostStatus == HiringPostStatus.Open)
            .ToListAsync(cancellationToken);

        foreach (var post in openPosts)
        {
            post.HiringPostStatus = HiringPostStatus.Closed;
        }

        await dbContext.SaveChangesAsync(cancellationToken);

        // Everyone who was counting on this job, and nobody who called it off. The workers matter
        // most here: a worker who is not told travels to a job that is not happening.
        await publisher.Publish(
            new BookingCancelledEvent(
                booking.Id,
                isCustomer,
                booking.CustomerProfile.UserId,
                booking.BusinessOwnerProfile.UserId,
                booking.WorkerAssignments
                    .Where(a => a.AssignmentStatus is BookingWorkerAssignmentStatus.Assigned
                        or BookingWorkerAssignmentStatus.Accepted)
                    .Select(a => a.WorkerProfile.UserId)
                    .ToList(),
                booking.BusinessOwnerProfile.BusinessName,
                NotificationText.Person(
                    booking.CustomerProfile.User.FirstName,
                    booking.CustomerProfile.User.LastName),
                booking.ScheduledDate),
            cancellationToken);

        // Either side may cancel; only the business gets the crew back.
        return booking.ToDto(includeCrew: isBusiness);
    }
}
