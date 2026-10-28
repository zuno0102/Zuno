using MediatR;
using Zuno.Application.Common.Interfaces;
using Zuno.Application.Modules.Booking.Common;
using Zuno.Application.Modules.Booking.DTOs;
using Zuno.Application.Modules.Booking.Events;
using Zuno.Domain.Enums;
using Zuno.Domain.Exceptions;

namespace Zuno.Application.Modules.Booking.Commands.StartBookingWork;

/// <summary>
/// Moves a confirmed order to in-progress.
/// </summary>
/// <remarks>
/// An explicit action rather than something inferred. The order used to flip itself the moment a
/// worker accepted, which could be weeks before the event — so "in progress" told a business
/// nothing about whether the job had actually started.
/// </remarks>
public class StartBookingWorkCommandHandler(
    ICurrentUserService currentUserService,
    IDateTimeProvider dateTimeProvider,
    IBusinessOwnerProfileRepository businessOwnerProfileRepository,
    IBookingRepository bookingRepository,
    IApplicationDbContext dbContext,
    IPublisher publisher) : IRequestHandler<StartBookingWorkCommand, BookingDto>
{
    public async Task<BookingDto> Handle(
        StartBookingWorkCommand request,
        CancellationToken cancellationToken)
    {
        var userId = currentUserService.UserId
            ?? throw new UnauthorizedAccessException("User is not authenticated.");

        // Null for a worker, which is the ordinary case for a lead: most of them have no business
        // of their own, so this can no longer be a precondition.
        var businessProfile = await businessOwnerProfileRepository.GetByUserIdAsync(userId, cancellationToken);

        var booking = await bookingRepository.GetByIdAsync(request.BookingId, cancellationToken)
            ?? throw new EntityNotFoundException(nameof(Domain.Entities.Booking), request.BookingId);

        // The owner, or the lead the owner put on this one job. See BookingWorkControl.
        if (!BookingWorkControl.MayMoveWork(booking, userId, businessProfile?.Id))
        {
            throw new UnauthorizedAccessException(
                "Only the business, or the worker leading this job, can start the work.");
        }

        if (booking.BookingStatus != BookingStatus.Confirmed)
        {
            throw new DomainException(booking.BookingStatus switch
            {
                BookingStatus.Pending => "Confirm this order before starting the work.",
                BookingStatus.InProgress => "This work has already been started.",
                BookingStatus.Completed => "This order is already finished.",
                BookingStatus.Cancelled => "This order was cancelled.",
                _ => "This order cannot be started.",
            });
        }

        // Somebody has to actually be on the job. An order with no crew that has "started" is a
        // claim the business cannot back up.
        if (booking.AcceptedCrewCount == 0)
        {
            throw new DomainException(
                "Nobody has accepted this job yet — assign a worker, or hire a crew, before starting.");
        }

        var now = dateTimeProvider.UtcNow;

        // Work cannot begin before the day it was booked for. The same rule hiring posts have
        // always had — without it here, a business could mark next month's wedding as under way
        // today, and every screen reading that status would be wrong for a month.
        if (booking.ScheduledDate > now)
        {
            throw new DomainException(
                "This work has not started yet — it begins on "
                + $"{booking.ScheduledDate.ToLocalTime():dd MMM HH:mm}.");
        }

        booking.BookingStatus = BookingStatus.InProgress;
        booking.WorkStartedAt = now;

        // The crew hired through a post for this order started with it, so the post — what their
        // job screens and schedules read — says so too.
        await LinkedHiringPostWork.MarkStartedAsync(dbContext, booking.Id, now, cancellationToken);

        await dbContext.SaveChangesAsync(cancellationToken);

        await publisher.Publish(
            new BookingWorkStartedEvent(
                booking.Id,
                booking.CustomerProfile.UserId,
                // Named as whoever actually started it. A lead starting the job and the customer
                // being told the business did is a small lie in the one line they read about it.
                BookingWorkControl.ActorName(booking, userId)),
            cancellationToken);

        // Answered as the caller sees it: a Lead moving the work is a worker, and is not shown the
        // customer's phone or the rest of the crew's wages.
        return booking.ToDto(booking.BusinessOwnerProfile.UserId == userId
            ? null
            : booking.WorkerAssignments.FirstOrDefault(a => a.WorkerProfile.UserId == userId)?.WorkerProfileId);
    }
}
