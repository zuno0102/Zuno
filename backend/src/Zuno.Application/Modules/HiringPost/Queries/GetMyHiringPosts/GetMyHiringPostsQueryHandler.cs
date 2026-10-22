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
    IApplicationDbContext dbContext) : IRequestHandler<GetMyHiringPostsQuery, List<HiringPostDto>>
{
    public async Task<List<HiringPostDto>> Handle(GetMyHiringPostsQuery request, CancellationToken cancellationToken)
    {
        var userId = currentUserService.UserId
            ?? throw new UnauthorizedAccessException("User is not authenticated.");

        var businessProfile = await businessOwnerProfileRepository.GetByUserIdAsync(userId, cancellationToken)
            ?? throw new EntityNotFoundException(nameof(BusinessOwnerProfile), userId);

        var posts = await dbContext.HiringPosts
            .AsNoTracking()
            .Include(p => p.BusinessOwnerProfile)
            .Include(p => p.ServiceSubCategory)
            .Include(p => p.Booking).ThenInclude(b => b!.BusinessService)
            .Include(p => p.Applications).ThenInclude(a => a.WorkerProfile).ThenInclude(wp => wp.User)
            .Include(p => p.Applications).ThenInclude(a => a.SalaryAdjustments)
            .Where(p => p.BusinessOwnerProfileId == businessProfile.Id)
            // Gone by with nobody hired: hidden at once, and soft-deleted by the cleanup job.
            .Where(Domain.Entities.HiringPost.WorthKeepingAt(dateTimeProvider.UtcNow))
            .OrderByDescending(p => p.CreatedDate)
            .ToListAsync(cancellationToken);

        return posts.Select(p => p.ToDto()).ToList();
    }
}
