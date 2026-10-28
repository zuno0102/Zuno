using MediatR;
using Microsoft.EntityFrameworkCore;
using Zuno.Application.Common.Interfaces;
using Zuno.Application.Modules.HiringPost.Common;
using Zuno.Application.Modules.HiringPost.DTOs;
using Zuno.Application.Modules.HiringPost.Events;
using Zuno.Application.Modules.Notifications.Common;
using Zuno.Domain.Entities;
using Zuno.Domain.Enums;
using Zuno.Domain.Exceptions;

namespace Zuno.Application.Modules.HiringPost.Commands.ApplyToHiringPost;

public class ApplyToHiringPostCommandHandler(
    ICurrentUserService currentUserService,
    IDateTimeProvider dateTimeProvider,
    IApplicationDbContext dbContext,
    IPublisher publisher) : IRequestHandler<ApplyToHiringPostCommand, HiringPostDto>
{
    public async Task<HiringPostDto> Handle(ApplyToHiringPostCommand request, CancellationToken cancellationToken)
    {
        var userId = currentUserService.UserId
            ?? throw new UnauthorizedAccessException("User is not authenticated.");

        var workerProfile = await dbContext.WorkerProfiles
            .FirstOrDefaultAsync(wp => wp.UserId == userId, cancellationToken)
            ?? throw new EntityNotFoundException(nameof(WorkerProfile), userId);

        var post = await dbContext.LoadHiringPostAsync(
            dbContext.HiringPosts
                .Include(p => p.BusinessOwnerProfile)
                .Where(p => p.Id == request.HiringPostId),
            cancellationToken)
            ?? throw new EntityNotFoundException(nameof(Domain.Entities.HiringPost), request.HiringPostId);

        // Checked before the status test so a worker is told the real reason: a finished job and a
        // filled vacancy are both "not open", but only one of them could ever change. A job that
        // has started but not finished still takes late joiners.
        if (post.IsHiringOver(dateTimeProvider.UtcNow))
        {
            throw new DomainException("Hiring for this job has closed.");
        }

        if (post.HiringPostStatus != HiringPostStatus.Open)
        {
            throw new DomainException("This hiring post is no longer open.");
        }

        if (post.Applications.Any(a => a.WorkerProfileId == workerProfile.Id))
        {
            throw new DomainException("You have already applied to this post.");
        }

        var application = new HiringPostApplication
        {
            HiringPostId = post.Id,
            WorkerProfileId = workerProfile.Id,
            WorkerProfile = workerProfile,
        };

        dbContext.HiringPostApplications.Add(application);
        await dbContext.SaveChangesAsync(cancellationToken);

        var updated = await dbContext.LoadHiringPostAsync(
            dbContext.HiringPosts
                .Include(p => p.BusinessOwnerProfile)
                .Where(p => p.Id == post.Id),
            cancellationToken)
            ?? throw new EntityNotFoundException(nameof(Domain.Entities.HiringPost), post.Id);

        // Read off the re-fetched post: the profile loaded above came back without its User, and
        // the waiting count has to include the application just written.
        var applicant = updated.Applications
            .First(a => a.WorkerProfileId == workerProfile.Id)
            .WorkerProfile.User;

        await publisher.Publish(
            new HiringPostAppliedEvent(
                updated.Id,
                updated.BusinessOwnerProfile.UserId,
                updated.Title,
                NotificationText.Person(applicant.FirstName, applicant.LastName),
                updated.Applications.Count(a =>
                    a.ApplicationStatus == HiringPostApplicationStatus.Applied)),
            cancellationToken);

        return updated.ToDto(workerProfile.Id);
    }
}
