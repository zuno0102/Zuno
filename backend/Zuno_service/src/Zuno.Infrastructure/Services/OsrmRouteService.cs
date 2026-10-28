using System.Globalization;
using System.Net.Http.Json;
using System.Text.Json;
using System.Text.Json.Serialization;
using Microsoft.Extensions.Caching.Memory;
using Microsoft.Extensions.Logging;
using Zuno.Application.Common.Interfaces;

namespace Zuno.Infrastructure.Services;

/// <inheritdoc />
/// <remarks>
/// <para>
/// OSRM, on the OpenStreetMap road network. Free and needs no key, which keeps it consistent with the
/// place search beside it.
/// </para>
/// <para>
/// <strong>The public demo server is not meant for production traffic.</strong> Its operators say so
/// plainly, and they can throttle or refuse requests at any time. It is fine while this is being
/// built and tried out; before real use the same interface should point at either a self-hosted OSRM
/// (the usual answer — the software is free, it is only the hosting that costs) or a commercial router.
/// Nothing above this class would change.
/// </para>
/// <para>
/// Routes are cached hard, because unlike a person's position a route between two fixed points does
/// not change from hour to hour — and a worker opening the same job twice should not cost two calls.
/// </para>
/// </remarks>
public class OsrmRouteService(
    HttpClient httpClient,
    IMemoryCache cache,
    ILogger<OsrmRouteService> logger) : IRouteService
{
    private static readonly TimeSpan CacheFor = TimeSpan.FromHours(24);

    public async Task<RouteResult?> GetRouteAsync(
        double fromLatitude,
        double fromLongitude,
        double toLatitude,
        double toLongitude,
        CancellationToken cancellationToken = default)
    {
        // Rounded to about 100m. Two requests from the same street corner to the same venue are the
        // same route, and asking twice would be waste on a provider we are a guest of.
        var cacheKey = "route:"
            + $"{fromLatitude:F3},{fromLongitude:F3}"
            + $"->{toLatitude:F3},{toLongitude:F3}";

        if (cache.TryGetValue(cacheKey, out RouteResult? cached))
        {
            return cached;
        }

        try
        {
            // OSRM takes longitude first, which is the opposite of how every other part of this
            // codebase orders a coordinate — worth stating, because transposing them returns a
            // perfectly plausible route somewhere else entirely.
            var invariant = CultureInfo.InvariantCulture;
            var url = "/route/v1/driving/"
                + $"{fromLongitude.ToString(invariant)},{fromLatitude.ToString(invariant)}"
                + $";{toLongitude.ToString(invariant)},{toLatitude.ToString(invariant)}"
                + "?overview=simplified"
                + "&geometries=geojson";

            var response = await httpClient.GetAsync(url, cancellationToken);

            if (!response.IsSuccessStatusCode)
            {
                logger.LogWarning(
                    "Route lookup returned {StatusCode}",
                    response.StatusCode);
                return null;
            }

            var payload = await response.Content.ReadFromJsonAsync<OsrmResponse>(
                cancellationToken: cancellationToken);

            var route = payload?.Routes?.FirstOrDefault();

            if (route?.Geometry?.Coordinates is not { Count: > 1 } coordinates)
            {
                return null;
            }

            var result = new RouteResult(
                DistanceKm: Math.Round(route.Distance / 1000, 1),
                DurationMinutes: Math.Round(route.Duration / 60),
                // Back to latitude-first for everybody else.
                Points: coordinates
                    .Where(pair => pair.Count >= 2)
                    .Select(pair => new RoutePoint(pair[1], pair[0]))
                    .ToList());

            cache.Set(cacheKey, result, CacheFor);
            return result;
        }
        catch (Exception exception) when (exception is HttpRequestException or TaskCanceledException or JsonException)
        {
            // Never fatal: the map can always fall back to a straight line between the two points.
            logger.LogWarning(exception, "Route lookup failed");
            return null;
        }
    }

    private sealed class OsrmResponse
    {
        [JsonPropertyName("routes")]
        public List<OsrmRoute>? Routes { get; set; }
    }

    private sealed class OsrmRoute
    {
        /// <summary>Metres.</summary>
        [JsonPropertyName("distance")]
        public double Distance { get; set; }

        /// <summary>Seconds.</summary>
        [JsonPropertyName("duration")]
        public double Duration { get; set; }

        [JsonPropertyName("geometry")]
        public OsrmGeometry? Geometry { get; set; }
    }

    private sealed class OsrmGeometry
    {
        /// <summary>GeoJSON pairs, longitude first.</summary>
        [JsonPropertyName("coordinates")]
        public List<List<double>>? Coordinates { get; set; }
    }
}
