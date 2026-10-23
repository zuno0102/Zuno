using MediatR;
using Microsoft.EntityFrameworkCore;
using Zuno.Application.Common.Interfaces;
using Zuno.Application.Common.Services;
using Zuno.Application.Modules.HiringPost.DTOs;
using Zuno.Application.Modules.HiringPost.Events;
using Zuno.Domain.Entities;
using Zuno.Domain.Enums;
using Zuno.Domain.Exceptions;

namespace Zuno.Application.Modules.HiringPost.Commands.InviteWorkerForDate;

/// <summary>
/// Creates the business's own event for one date and offers it to one worker, in a single step.
/// </summary>
/// <remarks>
/// The post and the offer are built together and written by one <c>SaveChanges</c>, so a refused
/// offer — a worker already busy that day, most often — leaves nothing behind. Creating the post
/// first and inviting afterwards would strand an empty job on the business's books every time the
/// clash check fired.
/// </remarks>
public class InviteWorkerForDateCommandHandler(
    ICurrentUserService currentUserService,
    IDateTimeProvider dateTimeProvider,
    IBusinessOwnerProfileRepository businessOwnerProfileRepository,
    IWorkerScheduleService workerScheduleService,
    IApplicationDbContext dbContext,
    IPublisher publisher) : IRequestHandler<InviteWorkerForDateCommand, HiringPostDto>
{
    public async Task<HiringPostDto> Handle(
        InviteWorkerForDateCommand request,
        CancellationToken cancellationToken)
    {
        var userId = currentUserService.UserId
            ?? throw new UnauthorizedAccessException("User is not authenticated.");

        var businessProfile = await businessOwnerProfileRepository.GetByUserIdAsync(userId, cancellationToken)
            ?? throw new EntityNotFoundException(nameof(BusinessOwnerProfile), userId);

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
        var now = dateTimeProvider.UtcNow;
        var endsAt = request.EventDate.AddMinutes(request.DurationMinutes);

        // Caught here rather than left to IsHiringOver further down, which would call a date in the
        // past "hiring has closed" — true of a post that ran its course, and baffling about one the
        // business is creating this second.
        if (endsAt <= now)
        {
            throw new DomainException(
                "That date has already passed. Pick a date in the future to offer them work.");
        }

        // Has this business already offered this worker this slot? The clash check below will not
        // say so: an unanswered offer reserves nothing by design, so that a business can line up
        // backups rather than have a place frozen by someone who never replies. That is right for
        // a post many people are being considered for, and wrong here, where pressing the button
        // twice would raise a second identical job for the same person.
        var alreadyOffered = await dbContext.HiringPosts
            .Where(p => p.BusinessOwnerProfileId == businessProfile.Id)
            .Where(p => p.EventDate < endsAt
                && p.EventDate.AddMinutes(p.DurationMinutes) > request.EventDate)
            .Where(p => p.Applications.Any(a =>
                a.WorkerProfileId == workerProfile.Id
                && (a.ApplicationStatus == HiringPostApplicationStatus.Confirmed
                    || a.ApplicationStatus == HiringPostApplicationStatus.Accepted)))
            .FirstOrDefaultAsync(cancellationToken);

        if (alreadyOffered is not null)
        {
            throw new DomainException(
                $"{workerName} already has work from you at that time — \"{alreadyOffered.Title}\". " +
                "Pick another date, or wait for them to answer that one.");
        }

        // The whole point of asking by date: the business finds out now that the worker is taken,
        // instead of after the offer sits unanswered. No post exists yet, so nothing to exclude.
        var clash = await workerScheduleService.FindConflictAsync(
            workerProfile.Id,
            request.EventDate,
            endsAt,
            cancellationToken: cancellationToken);

        if (clash is not null)
        {
            throw new DomainException(
                WorkerScheduleConflictMessages.ForBusiness(
                    clash, workerName, workerScheduleService.TravelBufferMinutes, request.EventDate));
        }

        // Checked rather than trusted: an id from another business's catalog, or none at all,
        // would otherwise be saved and only fail at the foreign key.
        ServiceSubCategory? subCategory = null;
        if (request.ServiceSubCategoryId is { } subCategoryId)
        {
            subCategory = await dbContext.ServiceSubCategories
                .FirstOrDefaultAsync(c => c.Id == subCategoryId, cancellationToken)
                ?? throw new DomainException("That kind of work is no longer listed. Pick another.");
        }

        // Named for the work when the business said what it is, since "Painting" tells a worker
        // more at a glance than the date they can already see on the offer.
        var title = string.IsNullOrWhiteSpace(request.Title)
            ? subCategory?.Name ?? $"Work on {request.EventDate.ToLocalTime():d MMM yyyy}"
            : request.Title.Trim();

        var location = string.IsNullOrWhiteSpace(request.Location)
            ? null
            : request.Location.Trim();

        var post = new Domain.Entities.HiringPost
        {
            BusinessOwnerProfileId = businessProfile.Id,
            BusinessOwnerProfile = businessProfile,
            // No customer order behind it: this is the business's own event, the same kind it
            // raises for its own work, and it reaches Status management the same way.
            BookingId = null,
            Title = title,
            EventDate = request.EventDate,
            DurationMinutes = request.DurationMinutes,
            ServiceSubCategoryId = subCategory?.Id,
            ServiceSubCategory = subCategory,
            // Typed out, so the post keeps no coordinates and never claims a precision the
            // business did not give it.
            Location = location,
            WorkersNeeded = 1,
            SalaryAmount = request.SalaryAmount,
            SalaryUnit = request.SalaryUnit,
            // Kept out of the open jobs feed. A worker only sees a closed post when they already
            // have an application on it, which this worker is about to, so the offer reaches them
            // and nobody else is shown a job meant for one person.
            //
            // Deliberately not SyncStatusToStaffing(), which would reopen it: a post with nobody
            // accepted yet counts as understaffed, and that is exactly the state an unanswered
            // offer is in. Should the worker turn it down, that same sync does reopen the post —
            // which is wanted, since the business still needs somebody on the day.
            HiringPostStatus = HiringPostStatus.Closed,
        };

        var application = new HiringPostApplication
        {
            HiringPost = post,
            WorkerProfileId = workerProfile.Id,
            WorkerProfile = workerProfile,
            // An offer, not a hire. The place is filled only when they accept — FilledCount counts
            // accepted applications alone — so nothing is assigned on the strength of an invite.
            ApplicationStatus = HiringPostApplicationStatus.Confirmed,
            RespondedAt = now,
            // Fixed now, so they answer on a figure that cannot move under them.
            AgreedSalaryAmount = request.SalaryAmount,
            AgreedSalaryUnit = request.SalaryUnit,
        };

        post.Applications.Add(application);
        dbContext.HiringPosts.Add(post);

        await dbContext.SaveChangesAsync(cancellationToken);

        await publisher.Publish(
            new WorkerInvitedToHiringPostEvent(
                post.Id,
                workerProfile.UserId,
                businessProfile.BusinessName,
                post.Title,
                request.SalaryAmount,
                request.SalaryUnit),
            cancellationToken);

        return post.ToDto();
    }
}
