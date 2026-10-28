using Microsoft.EntityFrameworkCore;
using Zuno.Application.Common;
using Zuno.Application.Common.Interfaces;
using Zuno.Application.Common.Settings;

namespace Zuno.Application.Modules.Booking.Common;

/// <summary>
/// Whether a pinned job location falls inside the districts a service is offered in.
/// </summary>
/// <remarks>
/// <para>
/// A business lists the districts it works in, and an order pinned outside them is a job nobody
/// agreed to travel to. Without this a customer in Bengaluru could book a Kanyakumari-only service.
/// </para>
/// <para>
/// <strong>Nearest headquarters, with slack at the border.</strong> There are no district polygons, only
/// one headquarters point per district, so "which district is this pin in" is answered by the nearest
/// headquarters. That is wrong near a border: Marthandam is in Kanyakumari but only about a dozen
/// kilometres further from Thiruvananthapuram's headquarters than from Nagercoil's. So a pin passes when
/// the nearest <em>served</em> headquarters is within the border slack of the nearest
/// headquarters overall. That forgives a border town and still refuses another city outright.
/// </para>
/// <para>
/// <strong>Never refuses what it cannot measure.</strong> Headquarters points exist only for the
/// curated states. If any served district has none, the check cannot judge the pin and lets it through,
/// the same rule the district data already follows elsewhere.
/// </para>
/// <para>
/// Both distances — the border slack and the outer limit — are platform settings
/// (<see cref="PlatformRules.ServiceAreaBorderSlackKm"/>, <see cref="PlatformRules.ServiceAreaMaxDistanceKm"/>).
/// </para>
/// </remarks>
public static class ServiceAreaCheck
{
    /// <summary>The result of a check: whether the pin is served, and the names of the served districts.</summary>
    public sealed record Result(bool IsServed, IReadOnlyList<string> ServedDistrictNames);

    public static async Task<Result> CheckAsync(
        Guid businessServiceId,
        decimal latitude,
        decimal longitude,
        PlatformRules rules,
        IApplicationDbContext dbContext,
        CancellationToken cancellationToken)
    {
        var served = await dbContext.BusinessServiceDistricts
            .Where(sd => sd.BusinessServiceId == businessServiceId)
            .Select(sd => new
            {
                sd.District.Name,
                Lat = sd.District.CentreLatitude,
                Lon = sd.District.CentreLongitude,
            })
            .ToListAsync(cancellationToken);

        var names = served.Select(s => s.Name).OrderBy(n => n).ToList();

        // Nothing listed means nothing to hold the pin against; the service validators require at
        // least one district, so this only covers data older than that rule.
        if (served.Count == 0 || served.Any(s => s.Lat is null || s.Lon is null))
        {
            return new Result(true, names);
        }

        var allCentres = await dbContext.Districts
            .Where(d => d.CentreLatitude != null && d.CentreLongitude != null)
            .Select(d => new { Lat = d.CentreLatitude!.Value, Lon = d.CentreLongitude!.Value })
            .ToListAsync(cancellationToken);

        var isServed = IsServed(
            (double)latitude,
            (double)longitude,
            served.Select(s => ((double)s.Lat!.Value, (double)s.Lon!.Value)).ToList(),
            allCentres.Select(c => ((double)c.Lat, (double)c.Lon)).ToList(),
            rules);

        return new Result(isServed, names);
    }

    /// <summary>The geometry alone, kept free of the database so it can be tested directly.</summary>
    public static bool IsServed(
        double latitude,
        double longitude,
        IReadOnlyList<(double Latitude, double Longitude)> servedCentres,
        IReadOnlyList<(double Latitude, double Longitude)> allCentres,
        PlatformRules rules)
    {
        if (servedCentres.Count == 0)
        {
            return true;
        }

        var nearestServedKm = servedCentres.Min(c => GeoDistance.HaversineKm(latitude, longitude, c.Latitude, c.Longitude));
        if (nearestServedKm > rules.ServiceAreaMaxDistanceKm)
        {
            return false;
        }

        var nearestAnyKm = allCentres.Count == 0
            ? nearestServedKm
            : allCentres.Min(c => GeoDistance.HaversineKm(latitude, longitude, c.Latitude, c.Longitude));

        return nearestServedKm <= nearestAnyKm + rules.ServiceAreaBorderSlackKm;
    }
}
