namespace Zuno.Application.Common.Interfaces;

/// <summary>
/// The way from one place to another by road.
/// </summary>
/// <remarks>
/// Separate from <see cref="IPlaceSearchService"/> because it answers a different question and will
/// likely move to a different provider: naming places and finding roads are sold separately.
/// </remarks>
public interface IRouteService
{
    /// <summary>
    /// The driving route between two points, or null when none can be found.
    /// </summary>
    /// <remarks>
    /// Null is a normal answer, not a failure: there is no road route across water, and a job on an
    /// island simply has none. Callers fall back to the straight line they can always draw.
    /// </remarks>
    Task<RouteResult?> GetRouteAsync(
        double fromLatitude,
        double fromLongitude,
        double toLatitude,
        double toLongitude,
        CancellationToken cancellationToken = default);
}

/// <summary>A road route, and what it costs to travel.</summary>
/// <param name="DistanceKm">Road distance, which is always longer than the straight line.</param>
/// <param name="DurationMinutes">Driving time as the router estimates it, ignoring traffic.</param>
/// <param name="Points">
/// The shape of the route, in order, for drawing. Simplified by the provider — enough to follow the
/// roads on a map, not enough to navigate turn by turn.
/// </param>
public record RouteResult(
    double DistanceKm,
    double DurationMinutes,
    IReadOnlyList<RoutePoint> Points);

/// <summary>One point along a route.</summary>
public record RoutePoint(double Latitude, double Longitude);
