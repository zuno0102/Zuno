using MediatR;
using Zuno.Application.Common.Interfaces;
using Zuno.Application.Modules.Booking.DTOs;
using Zuno.Application.Modules.Booking.Events;
using Zuno.Application.Modules.Notifications.Common;
using Zuno.Domain.Enums;
using Zuno.Domain.Exceptions;

namespace Zuno.Application.Modules.Booking.Commands.CompleteBooking;

public class CompleteBookingCommandHandler(
    ICurrentUserService currentUserService,
    IDateTimeProvider dateTimeProvider,
    IBookingRepository bookingRepository,
    IBusinessReputationService reputationService,
    IApplicationDbContext dbContext,
    IPublisher publisher) : IRequestHandler<CompleteBookingCommand, BookingDto>
{
    public async Task<BookingDto> Handle(CompleteBookingCommand request, CancellationToken cancellationToken)
    {
        var userId = currentUserService.UserId
            ?? throw new UnauthorizedAccessException("User is not authenticated.");

        var booking = await bookingRepository.GetByIdAsync(request.BookingId, cancellationToken)
            ?? throw new EntityNotFoundException(nameof(Domain.Entities.Booking), request.BookingId);

        var myAssignment = booking.WorkerAssignments.FirstOrDefault(a => a.WorkerProfile.UserId == userId)
            ?? throw new UnauthorizedAccessException("This booking is not assigned to you.");

        if (booking.BookingStatus != BookingStatus.InProgress
            || myAssignment.AssignmentStatus != BookingWorkerAssignmentStatus.Accepted)
        {
            throw new DomainException("Only an active, in-progress assignment can be marked completed.");
        }

        myAssignment.AssignmentStatus = BookingWorkerAssignmentStatus.Completed;
        myAssignment.CompletedAt = dateTimeProvider.UtcNow;

        var stillHasActiveCrew = booking.WorkerAssignments.Any(a =>
            a.AssignmentStatus is BookingWorkerAssignmentStatus.Assigned or BookingWorkerAssignmentStatus.Accepted);

        if (!stillHasActiveCrew)
        {
            booking.BookingStatus = BookingStatus.Completed;
            booking.CompletedAt = dateTimeProvider.UtcNow;
        }

        await dbContext.SaveChangesAsync(cancellationToken);

        // The business is told which of its crew has finished, whether or not that closes the whole
        // order — it is the business that owes this person their wage.
        await publisher.Publish(
            new BookingWorkerFinishedEvent(
                booking.Id,
                booking.BusinessOwnerProfile.UserId,
                NotificationText.Person(
                    myAssignment.WorkerProfile.User.FirstName,
                    myAssignment.WorkerProfile.User.LastName),
                booking.ScheduledDate),
            cancellationToken);

        if (booking.BookingStatus == BookingStatus.Completed)
        {
            await publisher.Publish(
                new BookingCompletedEvent(
                    booking.Id,
                    booking.CustomerProfile.UserId,
                    booking.CustomerProfile.User.Email,
                    booking.BusinessOwnerProfile.BusinessName),
                cancellationToken);

            // The last worker finishing is one of the two things an order waits on. Whether it
            // now counts depends on the wages as well, which is the service's to work out.
            await reputationService.RecalculateAndSaveAsync(
                booking.BusinessOwnerProfileId, cancellationToken);
        }

        return booking.ToDto(myAssignment.WorkerProfileId);
    }
}
