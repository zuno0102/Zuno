using MediatR;
using Zuno.Application.Common.Interfaces;
using Zuno.Application.Modules.Booking.DTOs;
using Zuno.Application.Modules.Booking.Events;
using Zuno.Application.Modules.Notifications.Common;
using Zuno.Domain.Enums;
using Zuno.Domain.Exceptions;

namespace Zuno.Application.Modules.Booking.Commands.RespondToAssignment;

public class RespondToAssignmentCommandHandler(
    ICurrentUserService currentUserService,
    IDateTimeProvider dateTimeProvider,
    IBookingRepository bookingRepository,
    IApplicationDbContext dbContext,
    IPublisher publisher) : IRequestHandler<RespondToAssignmentCommand, BookingDto>
{
    public async Task<BookingDto> Handle(RespondToAssignmentCommand request, CancellationToken cancellationToken)
    {
        var userId = currentUserService.UserId
            ?? throw new UnauthorizedAccessException("User is not authenticated.");

        var booking = await bookingRepository.GetByIdAsync(request.BookingId, cancellationToken)
            ?? throw new EntityNotFoundException(nameof(Domain.Entities.Booking), request.BookingId);

        var myAssignment = booking.WorkerAssignments.FirstOrDefault(a => a.WorkerProfile.UserId == userId)
            ?? throw new UnauthorizedAccessException("This booking is not assigned to you.");

        if (myAssignment.AssignmentStatus != BookingWorkerAssignmentStatus.Assigned)
        {
            throw new DomainException("This booking assignment has already been responded to.");
        }

        myAssignment.RespondedAt = dateTimeProvider.UtcNow;

        // Only the worker's own row moves. A worker answering an offer says nothing about whether
        // the order has been confirmed or the work has begun — those belong to the order's track,
        // and this handler used to overwrite both of them.
        myAssignment.AssignmentStatus = request.Accept
            ? BookingWorkerAssignmentStatus.Accepted
            : BookingWorkerAssignmentStatus.Rejected;

        await dbContext.SaveChangesAsync(cancellationToken);

        // The business is waiting on this answer — a decline especially, since it has to find
        // somebody else before the day.
        await publisher.Publish(
            new BookingAssignmentAnsweredEvent(
                booking.Id,
                booking.BusinessOwnerProfile.UserId,
                NotificationText.Person(
                    myAssignment.WorkerProfile.User.FirstName,
                    myAssignment.WorkerProfile.User.LastName),
                request.Accept,
                booking.ScheduledDate),
            cancellationToken);

        return booking.ToDto(myAssignment.WorkerProfileId);
    }
}
