namespace Zuno.Application.Common;

/// <summary>
/// Distance between two points on the earth, and the box that cheaply narrows a search to them.
/// </summary>
/// <remarks>
/// <para>
/// Deliberately plain arithmetic rather than PostGIS. The blocker is not deployment — it is that the
/// unit tests run handlers against an in-memory <c>DbSet</c>, where <c>EF.Functions.Distance</c> and
/// NetTopologySuite simply do not execute. Adopting a spatial provider would force every test of the
/// worker feed into an integration test against a live PostGIS container. Plain decimal comparisons
/// behave identically in Npgsql and in memory, which is what makes the two-step below possible.
/// </para>
/// <para>
/// <strong>Two steps, on purpose.</strong> <see cref="BoundingBox"/> produces four plain numbers a
/// database can compare against an index; <see cref="HaversineKm"/> then gives the true distance in
/// memory. The box is a square around a circle, so up to about 21% of what it returns is beyond the
/// radius and must be dropped by the second step. Filtering on the box alone would quietly include
/// jobs a fifth further away than asked for.
/// </para>
/// <para>
/// These are straight-line distances. Road distance in Kerala runs roughly 1.15 to 1.8 times
/// further — Trivandrum to Kollam is 54km as the crow flies and about 65km by road — so a figure
/// from here should be presented as a rough guide, never as travel distance.
/// </para>
/// </remarks>
public static class GeoDistance
{
    /// <summary>Mean earth radius in kilometres, as used by the haversine formula.</summary>
    private const double EarthRadiusKm = 6371.0088;

    /// <summary>Kilometres in one degree of latitude. Near enough constant everywhere.</summary>
    private const double LatitudeKmPerDegree = 110.574;

    /// <summary>Kilometres in one degree of longitude at the equator, narrowing with the cosine.</summary>
    private const double LongitudeKmPerDegreeAtEquator = 111.320;

    /// <summary>
    /// Straight-line distance in kilometres.
    /// </summary>
    public static double HaversineKm(
        double fromLatitude,
        double fromLongitude,
        double toLatitude,
        double toLongitude)
    {
        var deltaLat = ToRadians(toLatitude - fromLatitude);
        var deltaLon = ToRadians(toLongitude - fromLongitude);

        var a = Math.Sin(deltaLat / 2) * Math.Sin(deltaLat / 2)
            + Math.Cos(ToRadians(fromLatitude))
                * Math.Cos(ToRadians(toLatitude))
                * Math.Sin(deltaLon / 2)
                * Math.Sin(deltaLon / 2);

        // Atan2 rather than Asin: it stays accurate for antipodal points, where the argument to
        // Asin rounds to 1 and the result flattens out.
        return EarthRadiusKm * 2 * Math.Atan2(Math.Sqrt(a), Math.Sqrt(1 - a));
    }

    /// <summary>
    /// The smallest latitude/longitude rectangle containing every point within
    /// <paramref name="radiusKm"/> of the centre.
    /// </summary>
    /// <remarks>
    /// A rectangle, not a circle, so it can be expressed as four comparisons a database understands.
    /// The longitude span is always the wider one at Indian latitudes, and callers must still measure
    /// the true distance on whatever comes back.
    /// </remarks>
    public static (decimal MinLatitude, decimal MaxLatitude, decimal MinLongitude, decimal MaxLongitude)
        BoundingBox(double latitude, double longitude, double radiusKm)
    {
        var latitudeDelta = radiusKm / LatitudeKmPerDegree;

        var cosine = Math.Cos(ToRadians(latitude));

        // Guarded rather than trusted. India never comes near the poles, so this only fires on a
        // coordinate that is wrong — transposed on write, or a spoofed fix — and dividing by a cosine
        // approaching zero would otherwise produce an infinite span or a crash.
        var longitudeDelta = Math.Abs(cosine) < 0.01
            ? 180.0
            : radiusKm / (LongitudeKmPerDegreeAtEquator * Math.Abs(cosine));

        return (
            MinLatitude: (decimal)Math.Max(latitude - latitudeDelta, -90),
            MaxLatitude: (decimal)Math.Min(latitude + latitudeDelta, 90),
            MinLongitude: (decimal)Math.Max(longitude - longitudeDelta, -180),
            MaxLongitude: (decimal)Math.Min(longitude + longitudeDelta, 180));
    }

    private static double ToRadians(double degrees) => degrees * Math.PI / 180.0;
}
