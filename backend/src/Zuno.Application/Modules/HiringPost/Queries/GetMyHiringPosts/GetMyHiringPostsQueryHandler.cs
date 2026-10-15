using MediatR;
using Microsoft.EntityFrameworkCore;
using Zuno.Application.Common.Interfaces;
using Zuno.Application.Modules.HiringPost.DTOs;
using Zuno.Domain.Entities;
using Zuno.Domain.Exceptions;

namespace Zuno.Application.Modules.HiringPost.Queries.GetMyHiringPosts;

public class GetMyHiringPostsQueryHandler(
    ICurrentUserService currentUserService,
    IDateTimeProvider dateTimeProvider,
    IBusinessOwnerProfileRepository businessOwnerProfileRepository,
    IWorkerScheduleService workerScheduleService,
    IApplicationDbContext dbContext) : IRequestHandler<GetMyHiringPostsQuery, List<HiringPostDto>>
{
    public async Task<List<HiringPostDto>> Handle(GetMyHiringPostsQuery request, CancellationToken cancellationToken)
    {
        var userId = currentUserService.UserId
            ?? throw new UnauthorizedAccessException("User is not authenticated.");

        var businessProfile = await businessOwnerProfileRepository.GetByUserIdAsync(userId, cancellationToken)
            ?? throw new EntityNotFoundException(nameof(BusinessOwnerProfile), userId);

        var posts = await dbContext.HiringPosts
            .Include(p => p.BusinessOwnerProfile)
            .Include(p => p.ServiceSubCategory)
            .Include(p => p.Booking).ThenInclude(b => b!.BusinessService)
            .Include(p => p.Applications).ThenInclude(a => a.WorkerProfile).ThenInclude(wp => wp.User)
            .Include(p => p.Applications).ThenInclude(a => a.SalaryAdjustments)
            .Where(p => p.BusinessOwnerProfileId == businessProfile.Id)
            .OrderByDescending(p => p.CreatedDate)
            .ToListAsync(cancellationToken);

        var dtos = posts.Select(p => p.ToDto()).ToList();

        await AnnotateDelayRisksAsync(posts, dtos, cancellationToken);

        return dtos;
    }

    /// <summary>
    /// Marks any hired worker who is running late on an earlier job, so the business sees the
    /// risk to this one while there is still time to find cover — rather than discovering it
    /// when nobody turns up.
    /// </summary>
    private async Task AnnotateDelayRisksAsync(
        List<Domain.Entities.HiringPost> posts,
        List<HiringPostDto> dtos,
        CancellationToken cancellationToken)
    {
        var now = dateTimeProvider.UtcNow;

        // Only jobs that have not finished can still be rescued, so nothing else is worth asking about.
        var liveWorkerIds = posts
            .Where(p => p.WorkCompletedAt == null && p.EventEndDate > now)
            .SelectMany(p => p.Applications)
            .Where(a => a.ApplicationStatus == Domain.Enums.HiringPostApplicationStatus.Accepted)
            .Select(a => a.WorkerProfileId)
            .Distinct()
            .ToList();

        if (liveWorkerIds.Count == 0)
        {
            return;
        }

        var overruns = await workerScheduleService.FindOverrunsAsync(liveWorkerIds, cancellationToken);
        if (overruns.Count == 0)
        {
            return;
        }

        foreach (var (post, dto) in posts.Zip(dtos))
        {
            if (post.WorkCompletedAt is not null || post.EventEndDate <= now)
            {
                continue;
            }

            foreach (var application in dto.Applications)
            {
                if (!overruns.TryGetValue(application.WorkerProfileId, out var overrun))
                {
                    continue;
                }

                // A post never warns about itself running over — that tells the business nothing
                // they cannot already see from the card.
                if (overrun.HiringPostId == post.Id)
                {
                    continue;
                }

                application.DelayRisk =
                    $"May be late — \"{overrun.Title}\" was due to finish at " +
                    $"{overrun.DueToEndAt.ToLocalTime():HH:mm} and is {overrun.MinutesLate} minute(s) over.";
            }
        }
    }
}
