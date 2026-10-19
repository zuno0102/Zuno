using System.Net.Http.Json;
using System.Globalization;
using System.Text.Json;
using System.Text.Json.Serialization;
using Microsoft.Extensions.Caching.Memory;
using Microsoft.Extensions.Logging;
using Zuno.Application.Common.Interfaces;

namespace Zuno.Infrastructure.Services;

/// <inheritdoc />
/// <remarks>
/// <para>
/// OpenStreetMap's Nominatim: free, no API key, no billing account, and it covers Indian towns well.
/// The cost is its usage policy, which this class is built around — roughly one request per second,
/// a real User-Agent required, and no as-you-type searching.
/// </para>
/// <para>
/// Three things keep us inside that policy. It is only ever reached from our own server, never from
/// the app, so one identifiable client makes the requests. Results are cached, so the same query
/// typed by twenty workers costs one call. And the endpoint in front of it is rate limited per user.
/// </para>
/// <para>
/// The cache is in memory rather than a table, which is enough at this scale and needs no migration.
/// If this ever runs on more than one instance, a shared table is the upgrade — each instance would
/// otherwise keep its own copy.
/// </para>
/// </remarks>
public class NominatimPlaceSearchService(
    HttpClient httpClient,
    IMemoryCache cache,
    ILogger<NominatimPlaceSearchService> logger) : IPlaceSearchService
{
    /// <summary>Long enough to matter, short enough that a new place appears within a day.</summary>
    private static readonly TimeSpan CacheFor = TimeSpan.FromHours(12);

    /// <summary>Kept small: a worker picks from the first few or types something better.</summary>
    private const int MaxResults = 8;

    public async Task<IReadOnlyList<PlaceResult>> SearchAsync(
        string query,
        CancellationToken cancellationToken = default)
    {
        var trimmed = query.Trim();

        if (trimmed.Length < 3)
        {
            return [];
        }

        var cacheKey = $"place-search:{trimmed.ToLowerInvariant()}";

        if (cache.TryGetValue(cacheKey, out IReadOnlyList<PlaceResult>? cached) && cached is not null)
        {
            return cached;
        }

        try
        {
            // Restricted to India: this app hires within it, and the restriction removes a whole
            // class of confusing result — there is a Kollam in more than one country.
            var url = "/search"
                + $"?q={Uri.EscapeDataString(trimmed)}"
                + "&format=jsonv2"
                + $"&limit={MaxResults}"
                + "&countrycodes=in"
                + "&addressdetails=1";

            var response = await httpClient.GetAsync(url, cancellationToken);

            if (!response.IsSuccessStatusCode)
            {
                // Logged, not thrown. A place search that fails should leave the worker able to fall
                // back to their GPS position, not looking at an error screen.
                logger.LogWarning(
                    "Place search for {Query} returned {StatusCode}",
                    trimmed,
                    response.StatusCode);
                return [];
            }

            var body = await response.Content.ReadAsStringAsync(cancellationToken);
            logger.LogInformation(
                "Nominatim returned {Length} chars for {Query}: {Head}",
                body.Length,
                trimmed,
                body.Length > 160 ? body[..160] : body);

            var payload = JsonSerializer.Deserialize<List<NominatimPlace>>(
                body,
                new JsonSerializerOptions(JsonSerializerDefaults.Web));

            var results = (payload ?? [])
                .Where(p => p.Latitude is not null && p.Longitude is not null)
                .Select(p => ToResult(
                    p,
                    double.Parse(p.Latitude!, CultureInfo.InvariantCulture),
                    double.Parse(p.Longitude!, CultureInfo.InvariantCulture)))
                .ToList();

            cache.Set(cacheKey, (IReadOnlyList<PlaceResult>)results, CacheFor);

            return results;
        }
        catch (Exception exception) when (exception is HttpRequestException or TaskCanceledException or JsonException)
        {
            logger.LogWarning(exception, "Place search for {Query} failed", trimmed);
            return [];
        }
    }


    public async Task<PlaceResult?> ReverseAsync(
        double latitude,
        double longitude,
        bool precise = false,
        CancellationToken cancellationToken = default)
    {
        // Rounded to about 100m for the cache key. A worker standing still sends slightly different
        // fixes each time, and naming the same street corner twice should not cost two lookups. A
        // pinned house needs about 1m, or two neighbours would share one answer.
        var cacheKey = precise
            ? $"place-reverse-precise:{latitude:F5},{longitude:F5}"
            : $"place-reverse:{latitude:F3},{longitude:F3}";

        if (cache.TryGetValue(cacheKey, out PlaceResult? cached))
        {
            return cached;
        }

        try
        {
            // zoom=14 is roughly suburb or village level: the name a person would use for where they
            // are, rather than the building they happen to be standing in. zoom=18 is the building,
            // which is what a pinned job location wants.
            var url = "/reverse"
                + $"?lat={latitude.ToString(CultureInfo.InvariantCulture)}"
                + $"&lon={longitude.ToString(CultureInfo.InvariantCulture)}"
                + "&format=jsonv2"
                + (precise ? "&zoom=18" : "&zoom=14")
                + "&addressdetails=1";

            var response = await httpClient.GetAsync(url, cancellationToken);

            if (!response.IsSuccessStatusCode)
            {
                logger.LogWarning(
                    "Reverse lookup for {Latitude},{Longitude} returned {StatusCode}",
                    latitude,
                    longitude,
                    response.StatusCode);
                return null;
            }

            var body = await response.Content.ReadAsStringAsync(cancellationToken);
            var place = JsonSerializer.Deserialize<NominatimPlace>(
                body,
                new JsonSerializerOptions(JsonSerializerDefaults.Web));

            if (place?.DisplayName is null)
            {
                return null;
            }

            // The caller's own coordinates are kept, not the ones the provider echoes back: the
            // worker is where they are, not at the centre of the suburb that was matched.
            var result = ToResult(place, latitude, longitude);

            cache.Set(cacheKey, result, CacheFor);
            return result;
        }
        catch (Exception exception) when (exception is HttpRequestException or TaskCanceledException or JsonException)
        {
            // Never fatal. Failing to name a position must not stop somebody using it — the screen
            // falls back to calling it "your current location".
            logger.LogWarning(
                exception,
                "Reverse lookup for {Latitude},{Longitude} failed",
                latitude,
                longitude);
            return null;
        }
    }
    /// <summary>
    /// The first part of the display name, which is the bit somebody recognises.
    /// </summary>
    /// <remarks>
    /// Nominatim returns a full address like "Kazhakkoottam, Thiruvananthapuram, Kerala, 695582,
    /// India". Showing all of that as the label makes a list of results unreadable, so the head is
    /// used as the name and the whole string kept underneath to tell similar places apart.
    /// </remarks>
    private static string ShortNameOf(NominatimPlace place)
    {
        if (!string.IsNullOrWhiteSpace(place.Name))
        {
            return place.Name;
        }

        var display = place.DisplayName ?? string.Empty;
        var comma = display.IndexOf(',', StringComparison.Ordinal);
        return comma > 0 ? display[..comma] : display;
    }

    /// <summary>A provider row as our result, with the address split into the fields a form has.</summary>
    /// <remarks>
    /// Nominatim names the same thing differently by settlement size — a city is "city", a small
    /// town "town", a hamlet "village" — so each field takes the first one present.
    /// </remarks>
    private static PlaceResult ToResult(NominatimPlace place, double latitude, double longitude)
    {
        var a = place.Address;

        return new PlaceResult(
            Name: ShortNameOf(place),
            FullName: place.DisplayName ?? string.Empty,
            Latitude: latitude,
            Longitude: longitude,
            Street: FirstOf(a?.Road, a?.Pedestrian),
            Locality: FirstOf(a?.Suburb, a?.Neighbourhood, a?.Quarter, a?.Hamlet),
            City: FirstOf(a?.City, a?.Town, a?.Village, a?.Municipality, a?.County, a?.StateDistrict),
            State: FirstOf(a?.State),
            PostalCode: FirstOf(a?.Postcode));
    }

    private static string? FirstOf(params string?[] values) =>
        values.FirstOrDefault(v => !string.IsNullOrWhiteSpace(v))?.Trim();

    /// <summary>Only the fields this service reads. Nominatim returns a great deal more.</summary>
    private sealed class NominatimPlace
    {
        [JsonPropertyName("address")]
        public NominatimAddress? Address { get; set; }

        [JsonPropertyName("name")]
        public string? Name { get; set; }

        [JsonPropertyName("display_name")]
        public string? DisplayName { get; set; }

        // Strings, not numbers: Nominatim sends coordinates quoted.
        [JsonPropertyName("lat")]
        public string? Latitude { get; set; }

        [JsonPropertyName("lon")]
        public string? Longitude { get; set; }
    }

    /// <summary>The <c>addressdetails=1</c> breakdown.</summary>
    private sealed class NominatimAddress
    {
        [JsonPropertyName("road")] public string? Road { get; set; }
        [JsonPropertyName("pedestrian")] public string? Pedestrian { get; set; }
        [JsonPropertyName("suburb")] public string? Suburb { get; set; }
        [JsonPropertyName("neighbourhood")] public string? Neighbourhood { get; set; }
        [JsonPropertyName("quarter")] public string? Quarter { get; set; }
        [JsonPropertyName("hamlet")] public string? Hamlet { get; set; }
        [JsonPropertyName("city")] public string? City { get; set; }
        [JsonPropertyName("town")] public string? Town { get; set; }
        [JsonPropertyName("village")] public string? Village { get; set; }
        [JsonPropertyName("municipality")] public string? Municipality { get; set; }
        [JsonPropertyName("county")] public string? County { get; set; }
        [JsonPropertyName("state_district")] public string? StateDistrict { get; set; }
        [JsonPropertyName("state")] public string? State { get; set; }
        [JsonPropertyName("postcode")] public string? Postcode { get; set; }
    }
}
