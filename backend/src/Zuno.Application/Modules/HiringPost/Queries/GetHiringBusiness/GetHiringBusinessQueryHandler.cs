using MediatR;
using Microsoft.EntityFrameworkCore;
using Zuno.Application.Common;
using Zuno.Application.Common.Interfaces;
using Zuno.Application.Modules.HiringPost.DTOs;
using Zuno.Domain.Entities;
using Zuno.Domain.Enums;
using Zuno.Domain.Exceptions;
using Zuno.Domain.ValueObjects;

namespace Zuno.Application.Modules.HiringPost.Queries.GetHiringBusiness;

public class GetHiringBusinessQueryHandler(
    ICurrentUserService currentUserService,
    IDateTimeProvider dateTimeProvider,
    IApplicationDbContext dbContext,
    IBusinessTrustService trustService) : IRequestHandler<GetHiringBusinessQuery, HiringBusinessDto>
{
    public async Task<HiringBusinessDto> Handle(
        GetHiringBusinessQuery request,
        CancellationToken cancellationToken)
    {
        var userId = currentUserService.UserId
            ?? throw new UnauthorizedAccessException("User is not authenticated.");

        var workerProfile = await dbContext.WorkerProfiles
            .FirstOrDefaultAsync(wp => wp.UserId == userId, cancellationToken)
            ?? throw new EntityNotFoundException(nameof(WorkerProfile), userId);

        var business = await dbContext.BusinessOwnerProfiles
            .Include(p => p.BusinessAddress)
            .FirstOrDefaultAsync(p => p.Id == request.BusinessOwnerProfileId, cancellationToken)
            ?? throw new EntityNotFoundException(
                nameof(BusinessOwnerProfile), request.BusinessOwnerProfileId);

        var now = dateTimeProvider.UtcNow;

        // The same visibility rule the worker feed uses: still hiring, and the event has not gone.
        var openPosts = await dbContext.HiringPosts
            .Include(p => p.BusinessOwnerProfile)
            .Include(p => p.ServiceSubCategory)
            .Include(p => p.Applications).ThenInclude(a => a.WorkerProfile).ThenInclude(wp => wp.User)
            .Include(p => p.Applications).ThenInclude(a => a.SalaryAdjustments)
            .Where(p => p.BusinessOwnerProfileId == business.Id)
            .Where(p => p.HiringPostStatus == HiringPostStatus.Open)
            .Where(Domain.Entities.HiringPost.StillHiringAt(now))
            .OrderBy(p => p.EventDate)
            .ToListAsync(cancellationToken);

        var trust = await trustService.GetAsync(business.Id, cancellationToken);

        var hasPosition = request.Latitude is not null && request.Longitude is not null;

        var openPostDtos = openPosts.Select(post =>
        {
            var dto = post.ToDto(workerProfile.Id);

            // Same call, same rounding as the Find work feed. A job that reads 12.4 km there has to
            // read 12.4 km here, or the worker has two different answers to one question.
            if (hasPosition && post.Latitude is { } postLat && post.Longitude is { } postLon)
            {
                dto.DistanceKm = Math.Round(
                    GeoDistance.HaversineKm(
                        request.Latitude!.Value,
                        request.Longitude!.Value,
                        (double)postLat,
                        (double)postLon),
                    1);
            }

            return dto;
        }).ToList();

        return new HiringBusinessDto
        {
            Id = business.Id,
            BusinessName = business.BusinessName,
            LogoUrl = business.LogoUrl,
            City = business.BusinessAddress?.City,
            State = business.BusinessAddress?.State,
            Level = business.Level,
            LevelName = BusinessLevel.Name(business.Level),
            IsVerified = business.VerificationStatus == VerificationStatus.Verified,
            // Only the pay half. A worker is not deciding whether the food was any good.
            Pay = trust.Workers,
            OpenPosts = openPostDtos,
        };
    }
}
