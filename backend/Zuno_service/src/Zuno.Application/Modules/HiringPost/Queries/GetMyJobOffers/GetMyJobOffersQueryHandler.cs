using MediatR;
using Microsoft.EntityFrameworkCore;
using Zuno.Application.Common.Interfaces;
using Zuno.Application.Modules.HiringPost.Common;
using Zuno.Application.Modules.HiringPost.DTOs;
using Zuno.Domain.Entities;
using Zuno.Domain.Enums;
using Zuno.Domain.Exceptions;

namespace Zuno.Application.Modules.HiringPost.Queries.GetMyJobOffers;

public class GetMyJobOffersQueryHandler(
    ICurrentUserService currentUserService,
    IDateTimeProvider dateTimeProvider,
    IApplicationDbContext dbContext) : IRequestHandler<GetMyJobOffersQuery, List<HiringPostDto>>
{
    public async Task<List<HiringPostDto>> Handle(
        GetMyJobOffersQuery request,
        CancellationToken cancellationToken)
    {
        var userId = currentUserService.UserId
            ?? throw new UnauthorizedAccessException("User is not authenticated.");

        var workerProfile = await dbContext.WorkerProfiles
            .FirstOrDefaultAsync(wp => wp.UserId == userId, cancellationToken)
            ?? throw new EntityNotFoundException(nameof(WorkerProfile), userId);

        var now = dateTimeProvider.UtcNow;

        var posts = await dbContext.LoadHiringPostsAsync(
            dbContext.HiringPosts
                .Include(p => p.BusinessOwnerProfile)
                .Include(p => p.ServiceSubCategory)
                .Include(p => p.District)
                // Confirmed is the offer state: the business has picked this worker and nothing is
                // settled until they answer. Applied is their own doing and Accepted is already
                // decided, so neither belongs on a list of things waiting on them.
                .Where(p => p.Applications.Any(a =>
                    a.WorkerProfileId == workerProfile.Id
                    && a.ApplicationStatus == HiringPostApplicationStatus.Confirmed))
                // A job whose hiring has ended cannot be accepted, and an offer nobody can act on is
                // noise on a screen whose whole purpose is things that need answering.
                .Where(Domain.Entities.HiringPost.StillHiringAt(now))
                // Soonest first: the offer that expires first is the one to answer first.
                .OrderBy(p => p.EventDate),
            cancellationToken);

        return posts.Select(p => p.ToDto(workerProfile.Id)).ToList();
    }
}
