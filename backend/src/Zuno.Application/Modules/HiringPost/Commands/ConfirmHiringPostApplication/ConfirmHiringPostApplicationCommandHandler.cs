using MediatR;
using Microsoft.EntityFrameworkCore;
using Zuno.Application.Common.Interfaces;
using Zuno.Application.Common.Services;
using Zuno.Application.Modules.HiringPost.DTOs;
using Zuno.Application.Modules.HiringPost.Events;
using Zuno.Domain.Entities;
using Zuno.Domain.Enums;
using Zuno.Domain.Exceptions;

namespace Zuno.Application.Modules.HiringPost.Commands.ConfirmHiringPostApplication;

/// <summary>
/// The business's half of the hiring handshake: approving an applicant makes them an offer.
/// It does not fill the vacancy and does not put them on the worker roster — both wait until
/// the worker accepts in RespondToHiringPostOfferCommand.
/// </summary>
public class ConfirmHiringPostApplicationCommandHandler(
    ICurrentUserService currentUserService,
    IDateTimeProvider dateTimeProvider,
    IBusinessOwnerProfileRepository businessOwnerProfileRepository,
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

        var application = await dbContext.HiringPostApplications
            .Include(a => a.HiringPost).ThenInclude(p => p.BusinessOwnerProfile)
            .Include(a => a.HiringPost).ThenInclude(p => p.ServiceSubCategory)
            .Include(a => a.HiringPost).ThenInclude(p => p.Applications).ThenInclude(a => a.WorkerProfile).ThenInclude(wp => wp.User)
            .Include(a => a.HiringPost).ThenInclude(p => p.Applications).ThenInclude(a => a.SalaryAdjustments)
            .Include(a => a.WorkerProfile).ThenInclude(wp => wp.User)
            .FirstOrDefaultAsync(a => a.Id == request.ApplicationId, cancellationToken)
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

        // Checked again when the worker accepts, but doing it here too stops the business wasting
        // an offer — and a place in the head count — on someone who is already working elsewhere.
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

        application.ApplicationStatus = HiringPostApplicationStatus.Confirmed;
        application.RespondedAt = dateTimeProvider.UtcNow;

        // The salary the worker is being offered, captured as it stands now so they decide on a
        // figure that cannot move under them. It becomes binding the moment they accept.
        application.AgreedSalaryAmount = application.HiringPost.SalaryAmount;
        application.AgreedSalaryUnit = application.HiringPost.SalaryUnit;

        // Deliberately not closing the post here: the slot is not taken until the worker
        // accepts, so the vacancy stays open and visible in the meantime.
        application.HiringPost.SyncStatusToStaffing();

        await dbContext.SaveChangesAsync(cancellationToken);

        await publisher.Publish(
            new HiringPostApplicationConfirmedEvent(
                application.HiringPostId,
                application.WorkerProfile.UserId,
                application.HiringPost.BusinessOwnerProfile.BusinessName,
                application.HiringPost.Title),
            cancellationToken);

        return application.HiringPost.ToDto();
    }
}
