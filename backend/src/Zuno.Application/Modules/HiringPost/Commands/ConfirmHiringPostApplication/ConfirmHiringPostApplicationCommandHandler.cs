using MediatR;
using Microsoft.EntityFrameworkCore;
using Zuno.Application.Common.Interfaces;
using Zuno.Application.Common.Services;
using Zuno.Application.Modules.HiringPost.Common;
using Zuno.Application.Modules.HiringPost.DTOs;
using Zuno.Application.Modules.HiringPost.Events;
using Zuno.Domain.Entities;
using Zuno.Domain.Enums;
using Zuno.Domain.Exceptions;

namespace Zuno.Application.Modules.HiringPost.Commands.ConfirmHiringPostApplication;

/// <summary>
/// The business accepting someone who applied. The worker asked first, so this is the second yes:
/// they are hired on the spot — assigned, on the roster, on the order — with nothing more for them
/// to confirm. (Only an invitation, where the business asked first, waits on the worker.)
/// </summary>
public class ConfirmHiringPostApplicationCommandHandler(
    ICurrentUserService currentUserService,
    IDateTimeProvider dateTimeProvider,
    IBusinessOwnerProfileRepository businessOwnerProfileRepository,
    IBusinessWorkerRepository businessWorkerRepository,
    IWorkerScheduleService workerScheduleService,
    IApplicationDbContext dbContext,
    IPublisher publisher) : IRequestHandler<ConfirmHiringPostApplicationCommand, HiringPostDto>
{
    public async Task<HiringPostDto> Handle(ConfirmHiringPostApplicationCommand request, CancellationToken cancellationToken)
    {
        var userId = currentUserService.UserId
            ?? throw new UnauthorizedAccessException("User is not authenticated.");

        var businessProfile = await businessOwnerProfileRepository.GetByUserIdAsync(userId, cancellationToken)
            ?? throw new EntityNotFoundException(nameof(BusinessOwnerProfile), userId);

        var application = await dbContext.LoadHiringPostApplicationAsync(
            dbContext.HiringPostApplications
                .Include(a => a.HiringPost).ThenInclude(p => p.BusinessOwnerProfile)
                .Include(a => a.HiringPost).ThenInclude(p => p.ServiceSubCategory)
                .Include(a => a.WorkerProfile).ThenInclude(wp => wp.User)
                .Where(a => a.Id == request.ApplicationId),
            cancellationToken)
            ?? throw new EntityNotFoundException(nameof(HiringPostApplication), request.ApplicationId);

        if (application.HiringPost.BusinessOwnerProfileId != businessProfile.Id)
        {
            throw new UnauthorizedAccessException("This application does not belong to your business.");
        }

        if (application.ApplicationStatus != HiringPostApplicationStatus.Applied)
        {
            throw new DomainException("This application has already been responded to.");
        }

        if (application.HiringPost.IsHiringOver(dateTimeProvider.UtcNow))
        {
            throw new DomainException("Hiring for this job has closed.");
        }

        if (!application.HiringPost.CanOfferAnotherWorker)
        {
            var post = application.HiringPost;
            throw new DomainException(
                $"This post already has all {post.WorkersNeeded} place(s) filled. " +
                "Increase the workers needed to take on more.");
        }

        // The only clash check this hire gets, so it is the real one: a worker can be in one place at
        // a time, and their diary may have filled up since they applied.
        var conflictingJob = await workerScheduleService.FindConflictAsync(
            application.WorkerProfileId,
            application.HiringPost.EventDate,
            application.HiringPost.EventEndDate,
            excludeHiringPostId: application.HiringPost.Id,
            cancellationToken: cancellationToken);

        if (conflictingJob is not null)
        {
            var workerName = $"{application.WorkerProfile.User.FirstName} {application.WorkerProfile.User.LastName}";
            throw new DomainException(
                WorkerScheduleConflictMessages.ForBusiness(
                    conflictingJob, workerName, workerScheduleService.TravelBufferMinutes,
                    application.HiringPost.EventDate));
        }

        var now = dateTimeProvider.UtcNow;
        application.RespondedAt = now;

        // The salary the worker applied for, captured as it stands now. It is binding from this
        // moment: the worker already said yes to it by applying.
        application.AgreedSalaryAmount = application.HiringPost.SalaryAmount;
        application.AgreedSalaryUnit = application.HiringPost.SalaryUnit;

        // The worker applied, so this is the second yes: hired now, not offered.
        await HiringPostHire.CompleteAsync(
            application, businessWorkerRepository, dbContext, now, cancellationToken);

        await dbContext.SaveChangesAsync(cancellationToken);

        await publisher.Publish(
            new HiringPostApplicantHiredEvent(
                application.HiringPostId,
                application.WorkerProfile.UserId,
                application.HiringPost.BusinessOwnerProfile.BusinessName,
                application.HiringPost.Title),
            cancellationToken);

        return application.HiringPost.ToDto();
    }
}
