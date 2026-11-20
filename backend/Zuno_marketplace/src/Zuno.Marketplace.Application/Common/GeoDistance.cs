namespace Zuno.Marketplace.Application.Common;

/// <summary>
/// Straight-line distance between two points, for "near you" — the same formula as the Service API's
/// <c>GeoDistance</c> (Marketplace is its own deployable, so it cannot share that file). Plain
/// arithmetic, so it runs the same in tests and in production; a rough guide, not road distance.
/// </summary>
internal static class GeoDistance
{
    private const double EarthRadiusKm = 6371.0088;

    public static double HaversineKm(double fromLatitude, double fromLongitude, double toLatitude, double toLongitude)
    {
        var deltaLat = ToRadians(toLatitude - fromLatitude);
        var deltaLon = ToRadians(toLongitude - fromLongitude);
        var a = Math.Sin(deltaLat / 2) * Math.Sin(deltaLat / 2)
            + Math.Cos(ToRadians(fromLatitude)) * Math.Cos(ToRadians(toLatitude)) * Math.Sin(deltaLon / 2) * Math.Sin(deltaLon / 2);
        return EarthRadiusKm * 2 * Math.Atan2(Math.Sqrt(a), Math.Sqrt(1 - a));
    }

    private static double ToRadians(double degrees) => degrees * Math.PI / 180.0;
}
