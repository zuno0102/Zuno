using MediatR;
using Microsoft.EntityFrameworkCore;
using Zuno.Application.Common.Interfaces;
using Zuno.Application.Modules.HiringPost.DTOs;
using Zuno.Domain.Entities;
using Zuno.Domain.Exceptions;

namespace Zuno.Application.Modules.HiringPost.Commands.CompleteHiringPostWork;

/// <summary>
/// Marks the work done. Its real effect is on the crew: a completed job stops occupying their
/// day, so a two-hour booking that wrapped up early releases everyone for other work instead of
/// holding them until the scheduled end time.
/// </summary>
public class CompleteHiringPostWorkCommandHandler(
    ICurrentUserService currentUserService,
    IDateTimeProvider dateTimeProvider,
    IBusinessOwnerProfileRepository businessOwnerProfileRepository,
    IBusinessReputationService reputationService,
    IApplicationDbContext dbContext) : IRequestHandler<CompleteHiringPostWorkCommand, HiringPostDto>
{
    public async Task<HiringPostDto> Handle(CompleteHiringPostWorkCommand request, CancellationToken cancellationToken)
    {
        var userId = currentUserService.UserId
            ?? throw new UnauthorizedAccessException("User is not authenticated.");

        var businessProfile = await businessOwnerProfileRepository.GetByUserIdAsync(userId, cancellationToken)
            ?? throw new EntityNotFoundException(nameof(BusinessOwnerProfile), userId);

        var post = await dbContext.HiringPosts
            .Include(p => p.BusinessOwnerProfile)
            .Include(p => p.Applications).ThenInclude(a => a.WorkerProfile).ThenInclude(wp => wp.User)
            .Include(p => p.Applications).ThenInclude(a => a.SalaryAdjustments)
            .FirstOrDefaultAsync(p => p.Id == request.HiringPostId, cancellationToken)
            ?? throw new EntityNotFoundException(nameof(Domain.Entities.HiringPost), request.HiringPostId);

        if (post.BusinessOwnerProfileId != businessProfile.Id)
        {
            throw new UnauthorizedAccessException("This hiring post does not belong to your business.");
        }

        if (post.WorkCompletedAt is not null)
        {
            throw new DomainException("This work has already been marked completed.");
        }

        var now = dateTimeProvider.UtcNow;

        if (post.EventDate > now)
        {
            throw new DomainException(
                $"This work has not started yet — it begins on {post.EventDate.ToLocalTime():dd MMM HH:mm}.");
        }

        // Finishing something never started leaves a job with no beginning, which makes its
        // progress unreadable on screen and its duration unknowable afterwards.
        if (post.WorkStartedAt is null)
        {
            throw new DomainException("Start the work before marking it completed.");
        }

        post.WorkCompletedAt = now;

        await dbContext.SaveChangesAsync(cancellationToken);

        // Marking the work done can be the last thing a job was waiting on — a crew paid in
        // advance only becomes a completed job at this moment, and nothing recalculated here
        // before, so the credit never arrived.
        await reputationService.RecalculateAndSaveAsync(post.BusinessOwnerProfileId, cancellationToken);

        return post.ToDto();
    }
}
