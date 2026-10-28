using MediatR;
using Microsoft.EntityFrameworkCore;
using Zuno.Application.Common.Interfaces;
using Zuno.Application.Modules.HiringPost.Common;
using Zuno.Application.Modules.HiringPost.DTOs;
using Zuno.Domain.Entities;
using Zuno.Domain.Exceptions;

namespace Zuno.Application.Modules.HiringPost.Commands.StartHiringPostWork;

/// <summary>
/// Marks the crew as having started.
/// </summary>
/// <remarks>
/// The point where a job stops being a plan and becomes work in progress. Recording it lets the
/// app distinguish a job under way from one merely scheduled — a distinction the event date alone
/// cannot make, since a date passes whether or not anybody turned up.
/// </remarks>
public class StartHiringPostWorkCommandHandler(
    ICurrentUserService currentUserService,
    IDateTimeProvider dateTimeProvider,
    IBusinessOwnerProfileRepository businessOwnerProfileRepository,
    IApplicationDbContext dbContext) : IRequestHandler<StartHiringPostWorkCommand, HiringPostDto>
{
    public async Task<HiringPostDto> Handle(StartHiringPostWorkCommand request, CancellationToken cancellationToken)
    {
        var userId = currentUserService.UserId
            ?? throw new UnauthorizedAccessException("User is not authenticated.");

        // Null for a worker: the Lead the owner named on this own event may start it too.
        var businessProfile = await businessOwnerProfileRepository.GetByUserIdAsync(userId, cancellationToken);

        var post = await dbContext.LoadHiringPostAsync(
            dbContext.HiringPosts
                .Include(p => p.BusinessOwnerProfile)
                .Where(p => p.Id == request.HiringPostId),
            cancellationToken)
            ?? throw new EntityNotFoundException(nameof(Domain.Entities.HiringPost), request.HiringPostId);

        if (!HiringPostWorkControl.MayMoveWork(post, userId, businessProfile?.Id))
        {
            throw new UnauthorizedAccessException(
                "Only the business, or the worker leading this job, can start the work.");
        }

        if (post.WorkStartedAt is not null)
        {
            throw new DomainException("This work has already been started.");
        }

        if (post.WorkCompletedAt is not null)
        {
            throw new DomainException("This work is already finished.");
        }

        if (post.FilledCount == 0)
        {
            throw new DomainException("Nobody has been hired for this job yet.");
        }

        var now = dateTimeProvider.UtcNow;

        if (post.EventDate > now)
        {
            throw new DomainException(
                $"This work has not started yet — it begins on {post.EventDate.ToLocalTime():dd MMM HH:mm}.");
        }

        post.WorkStartedAt = now;

        await dbContext.SaveChangesAsync(cancellationToken);

        return post.ToDto(HiringPostWorkControl.WorkerViewer(post, userId, businessProfile?.Id));
    }
}
