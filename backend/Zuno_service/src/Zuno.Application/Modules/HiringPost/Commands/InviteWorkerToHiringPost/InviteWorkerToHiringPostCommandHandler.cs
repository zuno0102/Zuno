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

namespace Zuno.Application.Modules.HiringPost.Commands.InviteWorkerToHiringPost;

/// <summary>
/// Invites a specific worker straight onto a hiring post, for the common case where the business
/// already knows who it wants and does not need to wait for strangers to apply.
/// </summary>
/// <remarks>
/// Distinct from InviteWorkerCommand, which adds someone to the business's permanent roster and
/// has no bearing on any particular job. This creates the application in the
/// <see cref="HiringPostApplicationStatus.Confirmed"/> state — an offer — so the worker answers it
/// with the same Approve/Reject they would get had they applied themselves. The place is still
/// only filled when they accept: inviting someone does not hire them.
/// </remarks>
public class InviteWorkerToHiringPostCommandHandler(
    ICurrentUserService currentUserService,
    IDateTimeProvider dateTimeProvider,
    IBusinessOwnerProfileRepository businessOwnerProfileRepository,
    IWorkerScheduleService workerScheduleService,
    IApplicationDbContext dbContext,
    IPublisher publisher) : IRequestHandler<InviteWorkerToHiringPostCommand, HiringPostDto>
{
    public async Task<HiringPostDto> Handle(InviteWorkerToHiringPostCommand request, CancellationToken cancellationToken)
    {
        var userId = currentUserService.UserId
            ?? throw new UnauthorizedAccessException("User is not authenticated.");

        var businessProfile = await businessOwnerProfileRepository.GetByUserIdAsync(userId, cancellationToken)
            ?? throw new EntityNotFoundException(nameof(BusinessOwnerProfile), userId);

        // The booking comes along for two reasons: the guard below needs its status, and the
        // response is mapped straight back into the client's list — without it the post would
        // come home looking standalone and reappear in the pickers this guard closes.
        var post = await dbContext.LoadHiringPostAsync(
            dbContext.HiringPosts
                .Include(p => p.BusinessOwnerProfile)
                .Include(p => p.Booking).ThenInclude(b => b!.BusinessService)
                .Where(p => p.Id == request.HiringPostId),
            cancellationToken)
            ?? throw new EntityNotFoundException(nameof(Domain.Entities.HiringPost), request.HiringPostId);

        if (post.BusinessOwnerProfileId != businessProfile.Id)
        {
            throw new UnauthorizedAccessException("This hiring post does not belong to your business.");
        }

        var identifier = request.WorkerIdentifier.Trim();

        var workerProfile = await dbContext.WorkerProfiles
            .Include(wp => wp.User)
            .FirstOrDefaultAsync(
                wp => wp.User.Email == identifier || wp.User.PhoneNumber == identifier,
                cancellationToken);

        if (workerProfile is null)
        {
            throw new DomainException(
                $"No worker is registered with \"{identifier}\". They need a Zuno worker account " +
                "before they can be invited — or record them under \"Hired offline\" instead.");
        }

        var workerName = $"{workerProfile.User.FirstName} {workerProfile.User.LastName}";

        var existing = post.Applications.FirstOrDefault(a => a.WorkerProfileId == workerProfile.Id);
        if (existing is not null)
        {
            throw new DomainException(existing.ApplicationStatus switch
            {
                HiringPostApplicationStatus.Applied =>
                    $"{workerName} has already applied to this post — approve their application instead.",
                HiringPostApplicationStatus.Confirmed =>
                    $"{workerName} has already been invited and is yet to reply.",
                HiringPostApplicationStatus.Accepted =>
                    $"{workerName} is already working this post.",
                _ => $"{workerName} has already been turned down for this post.",
            });
        }

        if (post.IsHiringOver(dateTimeProvider.UtcNow))
        {
            throw new DomainException("Hiring for this job has closed.");
        }

        // A post raised from an order outlives that order: nothing closes it when the order is
        // finished or called off. So the order is asked directly, rather than trusted to have
        // shut the post down on its way out.
        if (post.Booking is { } booking)
        {
            if (booking.BookingStatus == BookingStatus.Cancelled)
            {
                throw new DomainException(
                    "That order was cancelled, so there is no longer work to invite anyone to.");
            }

            if (booking.BookingStatus == BookingStatus.Completed)
            {
                throw new DomainException(
                    "That order is already completed — you cannot invite anyone else to it.");
            }
        }

        if (!post.CanOfferAnotherWorker)
        {
            throw new DomainException(
                $"This post already has all {post.WorkersNeeded} place(s) filled. " +
                "Increase the workers needed to invite another.");
        }

        var clash = await workerScheduleService.FindConflictAsync(
            workerProfile.Id,
            post.EventDate,
            post.EventEndDate,
            excludeHiringPostId: post.Id,
            cancellationToken: cancellationToken);

        if (clash is not null)
        {
            throw new DomainException(
                WorkerScheduleConflictMessages.ForBusiness(
                    clash, workerName, workerScheduleService.TravelBufferMinutes, post.EventDate));
        }

        var application = new HiringPostApplication
        {
            HiringPostId = post.Id,
            HiringPost = post,
            WorkerProfileId = workerProfile.Id,
            WorkerProfile = workerProfile,
            ApplicationStatus = HiringPostApplicationStatus.Confirmed,
            RespondedAt = dateTimeProvider.UtcNow,
            // The rate they are being offered, fixed now so they decide on a figure that cannot
            // move under them — the same snapshot an approved applicant gets.
            AgreedSalaryAmount = post.SalaryAmount,
            AgreedSalaryUnit = post.SalaryUnit,
        };

        dbContext.HiringPostApplications.Add(application);

        // Holds a place but does not fill one, so the post stays open until they accept.
        post.SyncStatusToStaffing();

        await dbContext.SaveChangesAsync(cancellationToken);

        // The whole value of inviting by name is that the person hears about it. Without this they
        // find out whenever they next happen to open the Invitations tab.
        await publisher.Publish(
            new WorkerInvitedToHiringPostEvent(
                post.Id,
                workerProfile.UserId,
                post.BusinessOwnerProfile.BusinessName,
                post.Title,
                // The figure snapshotted onto the application above, not the post's current rate —
                // they must be told the number they will be held to.
                application.AgreedSalaryAmount ?? post.SalaryAmount,
                application.AgreedSalaryUnit ?? post.SalaryUnit),
            cancellationToken);

        return post.ToDto();
    }
}
