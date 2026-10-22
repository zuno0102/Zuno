using MediatR;
using Zuno.Application.Common.Interfaces;
using Zuno.Application.Modules.Booking.Common;
using Zuno.Application.Modules.Booking.DTOs;
using Zuno.Application.Modules.Booking.Events;
using Zuno.Domain.Enums;
using Zuno.Domain.Exceptions;

namespace Zuno.Application.Modules.Booking.Commands.CompleteBookingWork;

/// <summary>
/// The business closing the work on an order.
/// </summary>
/// <remarks>
/// Until now an order could only finish from the worker's side, one crew member at a time, and
/// only closed when the last of them remembered to tick it off. A business watching a job it ran
/// had no way to say it was done — so orders sat in progress indefinitely because somebody put
/// their phone away.
/// <para>
/// Finishing the order finishes the crew with it. Anyone still marked as working is marked done at
/// the same moment: the work they were on has ended, and leaving their row open would hold them
/// against other jobs in the clash check for a job that is over.
/// </para>
/// </remarks>
public class CompleteBookingWorkCommandHandler(
    ICurrentUserService currentUserService,
    IDateTimeProvider dateTimeProvider,
    IBusinessOwnerProfileRepository businessOwnerProfileRepository,
    IBookingRepository bookingRepository,
    IBusinessReputationService reputationService,
    IApplicationDbContext dbContext,
    IPublisher publisher) : IRequestHandler<CompleteBookingWorkCommand, BookingDto>
{
    public async Task<BookingDto> Handle(
        CompleteBookingWorkCommand request,
        CancellationToken cancellationToken)
    {
        var userId = currentUserService.UserId
            ?? throw new UnauthorizedAccessException("User is not authenticated.");

        // Null for a worker, which is the ordinary case for a lead — see StartBookingWork.
        var businessProfile = await businessOwnerProfileRepository.GetByUserIdAsync(userId, cancellationToken);

        var booking = await bookingRepository.GetByIdAsync(request.BookingId, cancellationToken)
            ?? throw new EntityNotFoundException(nameof(Domain.Entities.Booking), request.BookingId);

        if (!BookingWorkControl.MayMoveWork(booking, userId, businessProfile?.Id))
        {
            throw new UnauthorizedAccessException(
                "Only the business, or the worker leading this job, can finish the work.");
        }

        if (booking.BookingStatus != BookingStatus.InProgress)
        {
            throw new DomainException(booking.BookingStatus switch
            {
                BookingStatus.Pending => "Confirm this order before finishing it.",
                BookingStatus.Confirmed or BookingStatus.Assigned =>
                    "Start the work before marking it completed.",
                BookingStatus.Completed => "This order is already finished.",
                BookingStatus.Cancelled => "This order was cancelled.",
                _ => "This order cannot be completed.",
            });
        }

        var now = dateTimeProvider.UtcNow;

        foreach (var assignment in booking.WorkerAssignments)
        {
            if (assignment.AssignmentStatus is BookingWorkerAssignmentStatus.Assigned
                or BookingWorkerAssignmentStatus.Accepted)
            {
                assignment.AssignmentStatus = BookingWorkerAssignmentStatus.Completed;
                assignment.CompletedAt = now;
            }
        }

        booking.BookingStatus = BookingStatus.Completed;
        booking.CompletedAt = now;

        // The crew hired through a post for this order finished with it — and is paid through it.
        await LinkedHiringPostWork.MarkCompletedAsync(
            dbContext, booking.Id, booking.WorkStartedAt, now, cancellationToken);

        await dbContext.SaveChangesAsync(cancellationToken);

        // After the save, never before: the count is read back out of the database, so it can only
        // see this order as finished once the row actually is.
        // The order's own business, not the actor's — a lead has no business of their own.
        await reputationService.RecalculateAndSaveAsync(booking.BusinessOwnerProfileId, cancellationToken);

        // The same event the last worker finishing publishes. An order can close from either side,
        // and the customer's "rate them?" must not depend on which side happened to close it.
        await publisher.Publish(
            new BookingCompletedEvent(
                booking.Id,
                booking.CustomerProfile.UserId,
                booking.CustomerProfile.User.Email,
                booking.BusinessOwnerProfile.BusinessName),
            cancellationToken);

        return booking.ToDto();
    }
}
