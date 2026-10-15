using MediatR;
using Microsoft.EntityFrameworkCore;
using Zuno.Application.Common.Interfaces;
using Zuno.Application.Modules.HiringPost.DTOs;
using Zuno.Domain.Entities;
using Zuno.Domain.Enums;
using Zuno.Domain.Exceptions;

namespace Zuno.Application.Modules.HiringPost.Queries.GetMyPostJobs;

public class GetMyPostJobsQueryHandler(
    ICurrentUserService currentUserService,
    IApplicationDbContext dbContext) : IRequestHandler<GetMyPostJobsQuery, List<HiringPostDto>>
{
    public async Task<List<HiringPostDto>> Handle(
        GetMyPostJobsQuery request,
        CancellationToken cancellationToken)
    {
        var userId = currentUserService.UserId
            ?? throw new UnauthorizedAccessException("User is not authenticated.");

        var workerProfile = await dbContext.WorkerProfiles
            .FirstOrDefaultAsync(wp => wp.UserId == userId, cancellationToken)
            ?? throw new EntityNotFoundException(nameof(WorkerProfile), userId);

        var posts = await dbContext.HiringPosts
            .Include(p => p.BusinessOwnerProfile)
            .Include(p => p.ServiceSubCategory)
            .Include(p => p.District)
            .Include(p => p.Applications).ThenInclude(a => a.WorkerProfile).ThenInclude(wp => wp.User)
            .Include(p => p.Applications).ThenInclude(a => a.SalaryAdjustments)
            // Accepted only. An offer still waiting is an invitation, not a job they have, and the
            // ones they turned down are nobody's work.
            .Where(p => p.Applications.Any(a =>
                a.WorkerProfileId == workerProfile.Id
                && a.ApplicationStatus == HiringPostApplicationStatus.Accepted))
            .OrderBy(p => p.EventDate)
            .ToListAsync(cancellationToken);

        return posts.Select(p => p.ToDto(workerProfile.Id)).ToList();
    }
}
