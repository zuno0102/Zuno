using Microsoft.EntityFrameworkCore;
using Zuno.Application.Common;
using Zuno.Application.Common.Interfaces;
using Zuno.Application.Common.Settings;
using Zuno.Domain.Enums;

namespace Zuno.Application.Modules.HiringPost.Common;

/// <summary>
/// Puts a hiring post on the map: coordinates, how they were arrived at, and the district they fall in.
/// </summary>
/// <remarks>
/// Shared by create and update so a post is placed the same way however it was written. The district is
/// derived from the point rather than asked for, so the worker feed's district filter and its distance
/// search agree about where a job is.
/// </remarks>
public static class HiringPostLocation
{
    /// <summary>The precision a client may claim for a point it sends. Anything else is treated as pinned.</summary>
    public static HiringPostLocationPrecision ParsePrecision(string? value) =>
        string.Equals(value, nameof(HiringPostLocationPrecision.Geocoded), StringComparison.OrdinalIgnoreCase)
            ? HiringPostLocationPrecision.Geocoded
            : HiringPostLocationPrecision.Pinned;

    public static async Task PlaceAsync(
        Domain.Entities.HiringPost post,
        decimal latitude,
        decimal longitude,
        HiringPostLocationPrecision precision,
        PlatformRules rules,
        IApplicationDbContext dbContext,
        CancellationToken cancellationToken)
    {
        post.Latitude = Math.Round(latitude, 6);
        post.Longitude = Math.Round(longitude, 6);
        post.LocationPrecision = precision;
        post.DistrictId = await NearestDistrictIdAsync(
            latitude, longitude, rules.DistrictMatchMaxDistanceKm, dbContext, cancellationToken);
    }

    /// <summary>The district whose centre is closest to the point, or null if none is close enough.</summary>
    /// <param name="maxDistanceKm">
    /// A district centre further than this is not "the district it is in" — the point is somewhere the
    /// seed data does not cover, and leaving the district empty is more honest. A platform setting.
    /// </param>
    public static async Task<Guid?> NearestDistrictIdAsync(
        decimal latitude,
        decimal longitude,
        double maxDistanceKm,
        IApplicationDbContext dbContext,
        CancellationToken cancellationToken)
    {
        // A few hundred rows of three columns: cheaper to measure in memory than to teach the
        // database trigonometry, and it keeps GeoDistance the one place distance is computed.
        var centres = await dbContext.Districts
            .Where(d => d.CentreLatitude != null && d.CentreLongitude != null)
            .Select(d => new { d.Id, Lat = d.CentreLatitude!.Value, Lon = d.CentreLongitude!.Value })
            .ToListAsync(cancellationToken);

        var nearest = centres
            .Select(c => new
            {
                c.Id,
                Km = GeoDistance.HaversineKm((double)latitude, (double)longitude, (double)c.Lat, (double)c.Lon),
            })
            .OrderBy(c => c.Km)
            .FirstOrDefault();

        return nearest is not null && nearest.Km <= maxDistanceKm ? nearest.Id : null;
    }
}
