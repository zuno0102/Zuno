using MediatR;
using Microsoft.EntityFrameworkCore;
using Zuno.Application.Common.Interfaces;
using Zuno.Application.Common.Services;
using Zuno.Application.Modules.Booking.DTOs;
using Zuno.Application.Modules.Booking.Events;
using Zuno.Application.Modules.Notifications.Common;
using Zuno.Domain.Entities;
using Zuno.Domain.Enums;
using Zuno.Domain.Exceptions;

namespace Zuno.Application.Modules.Booking.Commands.AssignWorker;

public class AssignWorkerCommandHandler(
    ICurrentUserService currentUserService,
    IBusinessOwnerProfileRepository businessOwnerProfileRepository,
    IBusinessWorkerRepository businessWorkerRepository,
    IBookingRepository bookingRepository,
    IWorkerScheduleService workerScheduleService,
    IPlatformSettings platformSettings,
    IApplicationDbContext dbContext,
    IPublisher publisher) : IRequestHandler<AssignWorkerCommand, BookingDto>
{
    public async Task<BookingDto> Handle(AssignWorkerCommand request, CancellationToken cancellationToken)
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

        if (booking.BookingStatus is not (BookingStatus.Confirmed or BookingStatus.Assigned))
        {
            throw new DomainException("This booking must be confirmed before a worker can be assigned.");
        }

        if (booking.WorkerAssignments.Any(a => a.WorkerProfileId == request.WorkerProfileId))
        {
            throw new DomainException("This worker is already assigned to this booking.");
        }

        // No cap on how many people go on a job. A customer books a service, not a headcount —
        // the old limit came from the service definition, so a caterer whose "Catering" service
        // says 2 was refused a third pair of hands for a 300-guest wedding. How many it takes is
        // the business's judgement, and only the business knows the job.

        var businessWorker = await businessWorkerRepository.GetByBusinessAndWorkerAsync(
            businessProfile.Id, request.WorkerProfileId, cancellationToken);

        if (businessWorker is null || businessWorker.AssignmentStatus != BusinessWorkerStatus.Active)
        {
            throw new DomainException("The selected worker is not an active member of your business.");
        }

        // Compares the actual working hours rather than the calendar day, so a morning job and an
        // evening job no longer block each other, and it looks at hiring posts too — a worker hired
        // through one is just as unavailable as one assigned to a booking.
        var startsAt = request.ScheduledDate ?? booking.ScheduledDate;
        var jobMinutes = booking.BusinessServiceVariant?.EstimatedDurationMinutes
            ?? booking.BusinessService.EstimatedDurationMinutes
            ?? platformSettings.Current.DefaultJobMinutes;

        var clash = await workerScheduleService.FindConflictAsync(
            request.WorkerProfileId,
            startsAt,
            startsAt.AddMinutes(jobMinutes),
            excludeBookingId: booking.Id,
            cancellationToken: cancellationToken);

        if (clash is not null)
        {
            throw new DomainException(
                WorkerScheduleConflictMessages.ForBusiness(
                    clash, "This worker", workerScheduleService.TravelBufferMinutes, startsAt));
        }

        var workerProfile = await dbContext.WorkerProfiles
            .FirstOrDefaultAsync(wp => wp.Id == request.WorkerProfileId, cancellationToken)
            ?? throw new EntityNotFoundException(nameof(WorkerProfile), request.WorkerProfileId);

        dbContext.BookingWorkerAssignments.Add(new BookingWorkerAssignment
        {
            BookingId = booking.Id,
            WorkerProfileId = workerProfile.Id,
            WorkerProfile = workerProfile,
            // Null when the business pays this person outside Zuno. The validator has already
            // refused half a wage, so an amount here always has a unit with it.
            AgreedSalaryAmount = request.SalaryAmount,
            AgreedSalaryUnit = request.SalaryAmount.HasValue
                ? Enum.Parse<SalaryUnit>(request.SalaryUnit!, ignoreCase: true)
                : null,
        });

        if (request.ScheduledDate.HasValue)
        {
            booking.ScheduledDate = request.ScheduledDate.Value;
        }

        // The order's own status is left alone. Staffing is a separate track, derived from these
        // assignments — writing "Assigned" here used to erase the fact that the business had
        // confirmed the order at all.

        await dbContext.SaveChangesAsync(cancellationToken);

        var updated = await bookingRepository.GetByIdAsync(booking.Id, cancellationToken)
            ?? throw new EntityNotFoundException(nameof(Domain.Entities.Booking), booking.Id);

        // Read off the re-fetched order rather than the profile loaded above: that one came back
        // without its User, and the crew count has to include the row just written.
        var assigned = updated.WorkerAssignments
            .First(a => a.WorkerProfileId == workerProfile.Id);

        // One event, two people told — the customer that their crew is coming, the worker that they
        // have a job to answer. See BookingCrewAssignedEvent.
        await publisher.Publish(
            new BookingCrewAssignedEvent(
                updated.Id,
                updated.CustomerProfile.UserId,
                assigned.WorkerProfile.UserId,
                updated.BusinessOwnerProfile.BusinessName,
                NotificationText.Person(
                    assigned.WorkerProfile.User.FirstName,
                    assigned.WorkerProfile.User.LastName),
                updated.ActiveCrewCount,
                updated.ScheduledDate),
            cancellationToken);

        return updated.ToDto();
    }
}
