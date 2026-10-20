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

        // Three tries, cheapest and most exact first. Villages are where this matters: people type
        // "auttukonam, manalikarai" — a hamlet the free map has never heard of, then the village it
        // belongs to — and the exact search wants every word to match, so it found nothing at all.
        var results = await NominatimSearchAsync(trimmed, cancellationToken);

        // Spelling varies ("manalikkarai" / "Manalikarai"); Photon forgives that, Nominatim does not.
        if (results.Count == 0)
        {
            results = await PhotonSearchAsync(trimmed, cancellationToken);
        }

        // Still nothing: look for each part on its own, and say which part was found, so the person
        // gets the village and can drag the pin to their house rather than hitting a dead end.
        if (results.Count == 0)
        {
            foreach (var part in PartsOf(trimmed))
            {
                var partial = await NominatimSearchAsync(part, cancellationToken);
                if (partial.Count == 0)
                {
                    partial = await PhotonSearchAsync(part, cancellationToken);
                }

                if (partial.Count > 0)
                {
                    results = [.. partial.Select(p => p with { MatchedText = part })];
                    break;
                }
            }
        }

        cache.Set(cacheKey, (IReadOnlyList<PlaceResult>)results, CacheFor);
        return results;
    }

    /// <summary>
    /// The pieces of a typed place to try on their own: comma-separated parts, or the words of a
    /// multi-word query. Short scraps ("rd", "st") are skipped — they match half of India.
    /// </summary>
    internal static IReadOnlyList<string> PartsOf(string query)
    {
        var parts = query.Split(',', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries);
        if (parts.Length <= 1)
        {
            parts = query.Split(' ', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries);
        }

        return parts.Length <= 1
            ? []
            : [.. parts.Where(p => p.Length >= 4).Distinct(StringComparer.OrdinalIgnoreCase)];
    }

    private async Task<List<PlaceResult>> NominatimSearchAsync(string trimmed, CancellationToken cancellationToken)
    {
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

            return results;
        }
        catch (Exception exception) when (exception is HttpRequestException or TaskCanceledException or JsonException)
        {
            logger.LogWarning(exception, "Place search for {Query} failed", trimmed);
            return [];
        }
    }

    /// <summary>
    /// Photon (photon.komoot.io): the same free OpenStreetMap data, searched with typo tolerance.
    /// Only reached when the exact search found nothing, so it adds no load to ordinary searches.
    /// </summary>
    private async Task<List<PlaceResult>> PhotonSearchAsync(string trimmed, CancellationToken cancellationToken)
    {
        try
        {
            // India's bounding box, the same restriction the exact search applies by country code.
            var url = "https://photon.komoot.io/api/"
                + $"?q={Uri.EscapeDataString(trimmed)}"
                + $"&limit={MaxResults}"
                + "&lang=en"
                + "&bbox=68.1,6.5,97.4,35.7";

            using var response = await httpClient.GetAsync(url, cancellationToken);
            if (!response.IsSuccessStatusCode)
            {
                logger.LogWarning("Photon search for {Query} returned {StatusCode}", trimmed, response.StatusCode);
                return [];
            }

            var body = await response.Content.ReadAsStringAsync(cancellationToken);
            return ParsePhoton(body);
        }
        catch (Exception exception) when (exception is HttpRequestException or TaskCanceledException or JsonException)
        {
            logger.LogWarning(exception, "Photon search for {Query} failed", trimmed);
            return [];
        }
    }

    /// <summary>Photon's GeoJSON as our results. Internal so the mapping is tested without a network.</summary>
    internal static List<PlaceResult> ParsePhoton(string body)
    {
        var payload = JsonSerializer.Deserialize<PhotonResponse>(body, new JsonSerializerOptions(JsonSerializerDefaults.Web));

        return [.. (payload?.Features ?? [])
            .Where(f => f.Geometry?.Coordinates is { Count: >= 2 }
                && string.Equals(f.Properties?.CountryCode, "IN", StringComparison.OrdinalIgnoreCase))
            .Select(f =>
            {
                var p = f.Properties!;
                var lon = f.Geometry!.Coordinates![0];
                var lat = f.Geometry.Coordinates[1];
                var city = FirstOf(p.City, p.District, p.County);
                var name = FirstOf(p.Name, p.Street, city) ?? "Unnamed place";
                var full = string.Join(", ", new[] { p.Name, p.Street, p.Locality, p.District, p.City, p.County, p.State, p.Postcode }
                    .Where(s => !string.IsNullOrWhiteSpace(s))
                    .Distinct(StringComparer.OrdinalIgnoreCase));

                return new PlaceResult(
                    Name: name,
                    FullName: full,
                    Latitude: lat,
                    Longitude: lon,
                    Street: FirstOf(p.Street),
                    Locality: FirstOf(p.Locality, p.District),
                    City: city,
                    State: FirstOf(p.State),
                    PostalCode: FirstOf(p.Postcode));
            })];
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

    private sealed class PhotonResponse
    {
        [JsonPropertyName("features")] public List<PhotonFeature>? Features { get; set; }
    }

    private sealed class PhotonFeature
    {
        [JsonPropertyName("geometry")] public PhotonGeometry? Geometry { get; set; }
        [JsonPropertyName("properties")] public PhotonProperties? Properties { get; set; }
    }

    private sealed class PhotonGeometry
    {
        /// <summary>[longitude, latitude], GeoJSON order.</summary>
        [JsonPropertyName("coordinates")] public List<double>? Coordinates { get; set; }
    }

    private sealed class PhotonProperties
    {
        [JsonPropertyName("name")] public string? Name { get; set; }
        [JsonPropertyName("street")] public string? Street { get; set; }
        [JsonPropertyName("locality")] public string? Locality { get; set; }
        [JsonPropertyName("district")] public string? District { get; set; }
        [JsonPropertyName("city")] public string? City { get; set; }
        [JsonPropertyName("county")] public string? County { get; set; }
        [JsonPropertyName("state")] public string? State { get; set; }
        [JsonPropertyName("postcode")] public string? Postcode { get; set; }
        [JsonPropertyName("countrycode")] public string? CountryCode { get; set; }
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
