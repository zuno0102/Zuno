using MediatR;
using Microsoft.EntityFrameworkCore;
using Zuno.Application.Common.Interfaces;
using Zuno.Application.Common.Services;
using Zuno.Application.Modules.HiringPost.DTOs;
using Zuno.Application.Modules.HiringPost.Events;
using Zuno.Application.Modules.Notifications.Common;
using Zuno.Domain.Entities;
using Zuno.Domain.Enums;
using Zuno.Domain.Exceptions;

namespace Zuno.Application.Modules.HiringPost.Commands.RespondToHiringPostOffer;

/// <summary>
/// The worker's half of the hiring handshake. A business approval only creates an offer; the
/// slot is not filled until the worker says yes here. Declining releases the slot immediately,
/// which is what lets a vacancy shrink again — the business alone can never un-hire someone.
/// </summary>
public class RespondToHiringPostOfferCommandHandler(
    ICurrentUserService currentUserService,
    IDateTimeProvider dateTimeProvider,
    IBusinessWorkerRepository businessWorkerRepository,
    IWorkerScheduleService workerScheduleService,
    IApplicationDbContext dbContext,
    IPublisher publisher) : IRequestHandler<RespondToHiringPostOfferCommand, HiringPostDto>
{
    public async Task<HiringPostDto> Handle(RespondToHiringPostOfferCommand request, CancellationToken cancellationToken)
    {
        var userId = currentUserService.UserId
            ?? throw new UnauthorizedAccessException("User is not authenticated.");

        var workerProfile = await dbContext.WorkerProfiles
            .FirstOrDefaultAsync(wp => wp.UserId == userId, cancellationToken)
            ?? throw new EntityNotFoundException(nameof(WorkerProfile), userId);

        var application = await dbContext.HiringPostApplications
            .Include(a => a.HiringPost).ThenInclude(p => p.BusinessOwnerProfile)
            .Include(a => a.HiringPost).ThenInclude(p => p.ServiceSubCategory)
            .Include(a => a.HiringPost).ThenInclude(p => p.Applications).ThenInclude(x => x.WorkerProfile).ThenInclude(wp => wp.User)
            .Include(a => a.HiringPost).ThenInclude(p => p.Applications).ThenInclude(x => x.SalaryAdjustments)
            .FirstOrDefaultAsync(a => a.Id == request.ApplicationId, cancellationToken)
            ?? throw new EntityNotFoundException(nameof(HiringPostApplication), request.ApplicationId);

        if (application.WorkerProfileId != workerProfile.Id)
        {
            throw new UnauthorizedAccessException("This offer does not belong to you.");
        }

        if (application.ApplicationStatus != HiringPostApplicationStatus.Confirmed)
        {
            throw new DomainException(
                "There is no pending offer to respond to on this application.");
        }

        if (request.Accept)
        {
            // Stopped, finished or past its end: the place on offer no longer exists.
            if (application.HiringPost.IsHiringOver(dateTimeProvider.UtcNow))
            {
                throw new DomainException("Hiring for this job has closed.");
            }

            // Guard the race where two workers accept the last slot at the same moment.
            if (application.HiringPost.IsFullyStaffed)
            {
                throw new DomainException(
                    "This post has already been filled by other workers.");
            }

            // A worker can only be in one place at a time. Checked here rather than at the offer,
            // because this is the moment the commitment becomes real — and their diary may have
            // filled up while the offer sat unanswered.
            var post = application.HiringPost;
            var clash = await workerScheduleService.FindConflictAsync(
                workerProfile.Id,
                post.EventDate,
                post.EventEndDate,
                excludeHiringPostId: post.Id,
                cancellationToken: cancellationToken);

            if (clash is not null)
            {
                throw new DomainException(
                    WorkerScheduleConflictMessages.ForWorker(
                        clash, workerScheduleService.TravelBufferMinutes, post.EventDate));
            }

            application.ApplicationStatus = HiringPostApplicationStatus.Accepted;

            // Only now does the worker join the business's roster — accepting the job is what
            // makes the relationship real, not the business having offered it.
            var businessProfileId = application.HiringPost.BusinessOwnerProfileId;
            var businessWorker = await businessWorkerRepository.GetByBusinessAndWorkerAsync(
                businessProfileId, application.WorkerProfileId, cancellationToken);

            if (businessWorker is null)
            {
                businessWorkerRepository.Add(new BusinessWorker
                {
                    BusinessOwnerProfileId = businessProfileId,
                    WorkerProfileId = application.WorkerProfileId,
                    WorkerProfile = workerProfile,
                    AssignmentStatus = BusinessWorkerStatus.Active,
                    InvitedAt = application.RespondedAt ?? dateTimeProvider.UtcNow,
                    RespondedAt = dateTimeProvider.UtcNow,
                });
            }
            else if (businessWorker.AssignmentStatus != BusinessWorkerStatus.Active)
            {
                businessWorker.AssignmentStatus = BusinessWorkerStatus.Active;
                businessWorker.RespondedAt = dateTimeProvider.UtcNow;
            }

            await AssignToLinkedBookingAsync(application, cancellationToken);
        }
        else
        {
            application.ApplicationStatus = HiringPostApplicationStatus.Declined;

            // The offer was the only thing holding the agreed figure; drop it so a declined
            // offer leaves no trace of a salary the worker never took.
            application.AgreedSalaryAmount = null;
            application.AgreedSalaryUnit = null;
        }

        application.WorkerRespondedAt = dateTimeProvider.UtcNow;

        // Accepting may have filled the post; declining may have reopened it.
        application.HiringPost.SyncStatusToStaffing();

        await dbContext.SaveChangesAsync(cancellationToken);

        // The name comes off the application rather than the profile loaded above: that one was
        // fetched without its User, while the post's applications bring theirs along.
        var worker = application.HiringPost.Applications
            .First(a => a.Id == application.Id)
            .WorkerProfile.User;

        await publisher.Publish(
            new HiringPostOfferAnsweredEvent(
                application.HiringPostId,
                application.HiringPost.BusinessOwnerProfile.UserId,
                application.HiringPost.Title,
                NotificationText.Person(worker.FirstName, worker.LastName),
                request.Accept),
            cancellationToken);

        return application.HiringPost.ToDto(workerProfile.Id);
    }

    /// <summary>
    /// Puts a worker who just accepted onto the booking the post was raised for, if there is one.
    /// </summary>
    /// <remarks>
    /// Written directly rather than by sending <c>AssignWorkerCommand</c>, for one specific
    /// reason: that handler runs a clash check, and <c>WorkerScheduleService</c> counts accepted
    /// hiring-post applications as commitments. It would find the post this worker accepted a
    /// moment ago, see an exact overlap with itself, and refuse every single time. The real check
    /// has already run above, for this worker over this same window.
    ///
    /// The worker ends up holding two commitments for one event — the application and the
    /// assignment. That is harmless for clash detection, which simply reports the same conflict
    /// twice when a third job is checked.
    ///
    /// Nothing in here may throw. A problem on the booking side is not the worker's fault, and
    /// failing here would leave them un-hired after they had already said yes.
    /// </remarks>
    private async Task AssignToLinkedBookingAsync(
        HiringPostApplication application,
        CancellationToken cancellationToken)
    {
        if (application.HiringPost.BookingId is not { } bookingId)
        {
            return;
        }

        var booking = await dbContext.Bookings
            .Include(b => b.WorkerAssignments)
            .FirstOrDefaultAsync(b => b.Id == bookingId, cancellationToken);

        // The order was called off or finished while the offer sat unanswered.
        if (booking is null
            || booking.BookingStatus is BookingStatus.Cancelled or BookingStatus.Completed)
        {
            return;
        }

        // Already on it — added by hand while the offer sat unanswered. Nothing to write, and the
        // hire itself still stands.
        if (booking.WorkerAssignments.Any(a => a.WorkerProfileId == application.WorkerProfileId))
        {
            return;
        }

        // Deliberately no headcount limit. The post already said how many people the business
        // wanted and stopped taking workers once that many accepted — checking a second, unrelated
        // number off the service definition would quietly drop someone the business had just hired.

        // Accepted, not Assigned: the worker consented by taking the offer. Assigned would put the
        // same job back in front of them to accept a second time.
        dbContext.BookingWorkerAssignments.Add(new BookingWorkerAssignment
        {
            BookingId = booking.Id,
            WorkerProfileId = application.WorkerProfileId,
            AssignmentStatus = BookingWorkerAssignmentStatus.Accepted,
            RespondedAt = dateTimeProvider.UtcNow,
        });

        // The order's own status is untouched. Staffing is its own track now, worked out from
        // these assignments — hiring someone is not the business confirming the order, nor the
        // work having started.
    }
}
