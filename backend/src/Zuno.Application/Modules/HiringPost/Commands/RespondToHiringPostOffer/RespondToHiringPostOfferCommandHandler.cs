using MediatR;
using Microsoft.EntityFrameworkCore;
using Zuno.Application.Common.Interfaces;
using Zuno.Application.Common.Services;
using Zuno.Application.Modules.HiringPost.Common;
using Zuno.Application.Modules.HiringPost.DTOs;
using Zuno.Application.Modules.HiringPost.Events;
using Zuno.Application.Modules.Notifications.Common;
using Zuno.Domain.Entities;
using Zuno.Domain.Enums;
using Zuno.Domain.Exceptions;

namespace Zuno.Application.Modules.HiringPost.Commands.RespondToHiringPostOffer;

/// <summary>
/// The worker answering an invitation. The business asked first, so the worker saying yes here is
/// the second yes and hires them on the spot — no further step for the business. Declining releases
/// the slot immediately, which is what lets a vacancy shrink again.
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

        var application = await dbContext.LoadHiringPostApplicationAsync(
            dbContext.HiringPostApplications
                .Include(a => a.HiringPost).ThenInclude(p => p.BusinessOwnerProfile)
                .Include(a => a.HiringPost).ThenInclude(p => p.ServiceSubCategory)
                .Where(a => a.Id == request.ApplicationId),
            cancellationToken)
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

            // The business invited them, so this yes is the second one: they are hired now.
            await HiringPostHire.CompleteAsync(
                application, businessWorkerRepository, dbContext, dateTimeProvider.UtcNow, cancellationToken);
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
}
