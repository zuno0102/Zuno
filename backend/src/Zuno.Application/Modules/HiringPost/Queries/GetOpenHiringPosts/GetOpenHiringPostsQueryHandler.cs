using MediatR;
using Microsoft.EntityFrameworkCore;
using Zuno.Application.Common;
using Zuno.Application.Common.Interfaces;
using Zuno.Application.Modules.HiringPost.DTOs;
using Zuno.Domain.Entities;
using Zuno.Domain.Enums;
using Zuno.Domain.Exceptions;

namespace Zuno.Application.Modules.HiringPost.Queries.GetOpenHiringPosts;

public class GetOpenHiringPostsQueryHandler(
    ICurrentUserService currentUserService,
    IDateTimeProvider dateTimeProvider,
    IApplicationDbContext dbContext) : IRequestHandler<GetOpenHiringPostsQuery, List<HiringPostDto>>
{
    /// <summary>
    /// How many rows the bounding box may return before the true distance is worked out.
    /// </summary>
    /// <remarks>
    /// Generous on purpose. The box is a square around a circle, so up to about a fifth of what it
    /// returns is beyond the radius and gets dropped afterwards — capping tightly here would leave
    /// the caller short of the page they asked for, and would break nearest-first ordering by
    /// throwing away rows before they had been measured. This cap is the thing a proper spatial
    /// index replaces.
    /// </remarks>
    private const int BoundingBoxRowCap = 500;

    /// <summary>
    /// How many of the side groups to send: jobs the worker applied to that are out of range, and
    /// jobs with no location at all.
    /// </summary>
    /// <remarks>
    /// Small on purpose. Both groups exist so nothing is hidden, not so they can fill the screen —
    /// and in a database where most posts carry no coordinates, an uncapped "no location" group
    /// crowds out every job the worker actually asked for.
    /// </remarks>
    private const int SideGroupCap = 10;

    public async Task<List<HiringPostDto>> Handle(GetOpenHiringPostsQuery request, CancellationToken cancellationToken)
    {
        var userId = currentUserService.UserId
            ?? throw new UnauthorizedAccessException("User is not authenticated.");

        var workerProfile = await dbContext.WorkerProfiles
            .FirstOrDefaultAsync(wp => wp.UserId == userId, cancellationToken)
            ?? throw new EntityNotFoundException(nameof(WorkerProfile), userId);

        var now = dateTimeProvider.UtcNow;

        // A position only counts when both halves arrived. Half a coordinate is meaningless, and
        // silently treating a missing longitude as zero would place the worker in the Atlantic.
        var hasPosition = request.Latitude is { } && request.Longitude is { };

        var query = dbContext.HiringPosts
            .Include(p => p.BusinessOwnerProfile)
            .Include(p => p.ServiceSubCategory)
            .Include(p => p.District)
            .Include(p => p.Applications).ThenInclude(a => a.WorkerProfile).ThenInclude(wp => wp.User)
            .Include(p => p.Applications).ThenInclude(a => a.SalaryAdjustments)
            // A post is advertised while it still needs people and hiring has not ended — which
            // includes a job already under way, so a worker can still join late. Once the business
            // stops hiring or marks the work done, the post leaves this feed for everyone, applicants
            // included; anyone who actually worked it finds it in their job history instead.
            .Where(Domain.Entities.HiringPost.StillHiringAt(now))
            .Where(p => p.HiringPostStatus == HiringPostStatus.Open
                || p.Applications.Any(a => a.WorkerProfileId == workerProfile.Id));

        if (request.DistrictIds is { Count: > 0 } districtIds)
        {
            query = query.Where(p => p.DistrictId != null && districtIds.Contains(p.DistrictId.Value)
                || p.Applications.Any(a => a.WorkerProfileId == workerProfile.Id));
        }

        if (hasPosition && request.RadiusKm is { } radiusKm)
        {
            var box = GeoDistance.BoundingBox(request.Latitude!.Value, request.Longitude!.Value, radiusKm);

            // Four plain comparisons, which is the whole reason this runs in SQL rather than in
            // memory. The box is wider than the radius, so it over-selects and the real distance is
            // applied below.
            query = query.Where(p =>
                // A post with no position is never excluded by a radius — it is listed apart
                // instead, because a worker cannot be expected to know a job exists to look for.
                p.Latitude == null
                || p.Longitude == null
                || (p.Latitude >= box.MinLatitude
                    && p.Latitude <= box.MaxLatitude
                    && p.Longitude >= box.MinLongitude
                    && p.Longitude <= box.MaxLongitude)
                // An applied-to post survives any distance. This is not a nicety: it is the only
                // route a worker has to the payment screens for that job, so filtering it out
                // would stop somebody reporting that they were never paid for work they did.
                || p.Applications.Any(a => a.WorkerProfileId == workerProfile.Id));
        }

        var posts = await query
            .OrderByDescending(p => p.CreatedDate)
            .Take(hasPosition ? BoundingBoxRowCap : request.Take)
            .ToListAsync(cancellationToken);

        var results = posts.Select(post =>
        {
            var dto = post.ToDto(workerProfile.Id);

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
        });

        var all = results.ToList();

        // Ordered by event date, latest first, everywhere below. Distance has already decided what
        // is on the list at all, so the remaining question is when the work is; nearest only breaks
        // ties between jobs on the same day.
        static IEnumerable<HiringPostDto> ByDate(IEnumerable<HiringPostDto> source) => source
            .OrderByDescending(dto => dto.EventDate)
            .ThenBy(dto => dto.DistanceKm ?? double.MaxValue);

        if (!hasPosition)
        {
            return ByDate(all).Take(request.Take).ToList();
        }

        var radius = request.RadiusKm;

        // Three groups, kept apart and given their own share of the page.
        //
        // This is not presentation: it is what stops the feature collapsing. Posts with no
        // coordinates are deliberately never excluded by a radius — a worker cannot look for a job
        // they were never shown — but most posts in this database have none, so letting them compete
        // for the same page filled it entirely and pushed every nearby job off. They now get a small
        // fixed allowance instead.
        var near = all
            .Where(dto => dto.DistanceKm is { } km && (radius is null || km <= radius))
            .ToList();

        var nearIds = near.Select(dto => dto.Id).ToHashSet();

        // Beyond the radius but still shown, because this is the worker's only route to that job's
        // payment screens. Capped for the same reason as the group below.
        var appliedFurther = all
            .Where(dto => !nearIds.Contains(dto.Id)
                && dto.DistanceKm is not null
                && dto.MyApplicationStatus is not null)
            .ToList();

        var unlocated = all.Where(dto => dto.DistanceKm is null).ToList();

        return ByDate(near)
            .Take(request.Take)
            .Concat(ByDate(appliedFurther).Take(SideGroupCap))
            .Concat(ByDate(unlocated).Take(SideGroupCap))
            .ToList();
    }
}
