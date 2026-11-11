using MediatR;
using Microsoft.EntityFrameworkCore;
using Zuno.Application.Common;
using Zuno.Application.Common.Interfaces;

namespace Zuno.Application.Modules.Catalog.Queries.GetNearestDistrict;

/// <remarks>
/// The district whose headquarters is nearest, as <c>ServiceAreaCheck</c> already decides it for a
/// booking — there are no district outlines, only one headquarters point each. A point further than
/// the platform's service-area limit from every headquarters (abroad, or in a state without points)
/// gets no district, and the app keeps showing everywhere rather than guessing.
/// </remarks>
public class GetNearestDistrictQueryHandler(IApplicationDbContext dbContext, IPlatformSettings platformSettings)
    : IRequestHandler<GetNearestDistrictQuery, NearestDistrictDto?>
{
    public async Task<NearestDistrictDto?> Handle(GetNearestDistrictQuery request, CancellationToken cancellationToken)
    {
        var centres = await dbContext.Districts
            .AsNoTracking()
            .Where(d => d.CentreLatitude != null && d.CentreLongitude != null)
            .Select(d => new Centre(
                d.Id, d.Name, d.StateId, d.State.Name, (double)d.CentreLatitude!.Value, (double)d.CentreLongitude!.Value))
            .ToListAsync(cancellationToken);

        return Nearest(
            (double)request.Latitude,
            (double)request.Longitude,
            centres,
            platformSettings.Current.ServiceAreaMaxDistanceKm);
    }

    public sealed record Centre(Guid Id, string Name, Guid StateId, string StateName, double Latitude, double Longitude);

    /// <summary>The geometry alone, kept free of the database so it can be tested directly.</summary>
    public static NearestDistrictDto? Nearest(
        double latitude, double longitude, IReadOnlyList<Centre> centres, double maxDistanceKm)
    {
        if (centres.Count == 0)
        {
            return null;
        }

        var nearest = centres
            .Select(c => (Centre: c, Km: GeoDistance.HaversineKm(latitude, longitude, c.Latitude, c.Longitude)))
            .MinBy(x => x.Km);

        return nearest.Km > maxDistanceKm
            ? null
            : new NearestDistrictDto(
                nearest.Centre.Id, nearest.Centre.Name, nearest.Centre.StateId, nearest.Centre.StateName, Math.Round(nearest.Km, 1));
    }
}
