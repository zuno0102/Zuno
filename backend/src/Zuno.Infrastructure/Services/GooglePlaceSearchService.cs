using System.Globalization;
using System.Net.Http.Json;
using System.Text.Json.Serialization;
using Microsoft.Extensions.Caching.Memory;
using Microsoft.Extensions.Logging;
using Zuno.Application.Common.Interfaces;

namespace Zuno.Infrastructure.Services;

/// <inheritdoc />
/// <remarks>
/// <para>
/// Google: Places API (New) Text Search to find a place, Geocoding API to name a pinned point. Used
/// instead of OpenStreetMap whenever <c>GoogleMaps:ApiKey</c> is set, because Google knows the shops,
/// churches, halls and small lanes that OpenStreetMap has never been told about in most villages.
/// </para>
/// <para>
/// Server-side so the key never ships in the app, and cached like the free provider so the same
/// search typed twice is paid for once. Failures are logged and answered with "nothing found" —
/// the person can still drag the map to the place.
/// </para>
/// </remarks>
public class GooglePlaceSearchService(
    HttpClient httpClient,
    IMemoryCache cache,
    string apiKey,
    ILogger<GooglePlaceSearchService> logger) : IPlaceSearchService
{
    private static readonly TimeSpan CacheFor = TimeSpan.FromHours(12);
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

        var cacheKey = $"google-search:{trimmed.ToLowerInvariant()}";
        if (cache.TryGetValue(cacheKey, out IReadOnlyList<PlaceResult>? cached) && cached is not null)
        {
            return cached;
        }

        try
        {
            using var request = new HttpRequestMessage(HttpMethod.Post, "https://places.googleapis.com/v1/places:searchText")
            {
                Content = JsonContent.Create(new
                {
                    textQuery = trimmed,
                    regionCode = "IN",
                    languageCode = "en",
                    pageSize = MaxResults,
                }),
            };
            request.Headers.Add("X-Goog-Api-Key", apiKey);
            request.Headers.Add(
                "X-Goog-FieldMask",
                "places.displayName,places.formattedAddress,places.location,places.addressComponents");

            using var response = await httpClient.SendAsync(request, cancellationToken);
            if (!response.IsSuccessStatusCode)
            {
                logger.LogWarning(
                    "Google place search for {Query} returned {StatusCode}: {Body}",
                    trimmed,
                    response.StatusCode,
                    await response.Content.ReadAsStringAsync(cancellationToken));
                return [];
            }

            var payload = await response.Content.ReadFromJsonAsync<TextSearchResponse>(cancellationToken);
            var results = (payload?.Places ?? [])
                .Where(p => p.Location is not null)
                .Select(p => ToResult(
                    p.DisplayName?.Text,
                    p.FormattedAddress,
                    p.Location!.Latitude,
                    p.Location.Longitude,
                    p.AddressComponents?.Select(c => (c.LongText, c.Types)).ToList()))
                .ToList();

            cache.Set(cacheKey, (IReadOnlyList<PlaceResult>)results, CacheFor);
            return results;
        }
        catch (Exception exception) when (exception is HttpRequestException or TaskCanceledException or System.Text.Json.JsonException)
        {
            logger.LogWarning(exception, "Google place search for {Query} failed", trimmed);
            return [];
        }
    }

    public async Task<PlaceResult?> ReverseAsync(
        double latitude,
        double longitude,
        bool precise = false,
        CancellationToken cancellationToken = default)
    {
        // Same rounding as the free provider: ~1m for a pinned house, ~100m for "where am I".
        var cacheKey = precise
            ? $"google-reverse-precise:{latitude:F5},{longitude:F5}"
            : $"google-reverse:{latitude:F3},{longitude:F3}";

        if (cache.TryGetValue(cacheKey, out PlaceResult? cached))
        {
            return cached;
        }

        try
        {
            var url = "https://maps.googleapis.com/maps/api/geocode/json"
                + $"?latlng={latitude.ToString(CultureInfo.InvariantCulture)},{longitude.ToString(CultureInfo.InvariantCulture)}"
                + "&language=en"
                + $"&key={Uri.EscapeDataString(apiKey)}";

            var payload = await httpClient.GetFromJsonAsync<GeocodeResponse>(url, cancellationToken);
            if (payload?.Status != "OK" || payload.Results is not { Count: > 0 })
            {
                if (payload?.Status is not null and not "ZERO_RESULTS")
                {
                    logger.LogWarning(
                        "Google reverse lookup for {Latitude},{Longitude}: {Status} {Error}",
                        latitude, longitude, payload.Status, payload.ErrorMessage);
                }
                return null;
            }

            // The first result is the most specific — usually the street address under the pin.
            var best = payload.Results[0];
            var components = best.AddressComponents?.Select(c => (c.LongName, c.Types)).ToList();

            // The caller's own point is kept: the pin is where the person put it.
            var result = ToResult(null, best.FormattedAddress, latitude, longitude, components);
            cache.Set(cacheKey, result, CacheFor);
            return result;
        }
        catch (Exception exception) when (exception is HttpRequestException or TaskCanceledException or System.Text.Json.JsonException)
        {
            logger.LogWarning(exception, "Google reverse lookup for {Latitude},{Longitude} failed", latitude, longitude);
            return null;
        }
    }

    /// <summary>Google's typed address parts, as the fields a form has.</summary>
    internal static PlaceResult ToResult(
        string? name,
        string? formattedAddress,
        double latitude,
        double longitude,
        IReadOnlyList<(string? Text, List<string>? Types)>? components)
    {
        string? Of(params string[] types) => components?
            .FirstOrDefault(c => c.Types is not null && types.Any(t => c.Types.Contains(t)) && !string.IsNullOrWhiteSpace(c.Text))
            .Text?.Trim();

        var street = Of("route");
        var locality = Of("sublocality_level_1", "sublocality", "neighborhood", "sublocality_level_2");
        var city = Of("locality", "administrative_area_level_3", "administrative_area_level_2");
        var display = formattedAddress ?? string.Empty;

        var shortName = !string.IsNullOrWhiteSpace(name)
            ? name!
            : street ?? locality ?? city ?? (display.Contains(',') ? display[..display.IndexOf(',')] : display);

        return new PlaceResult(
            Name: shortName,
            FullName: display,
            Latitude: latitude,
            Longitude: longitude,
            Street: street,
            Locality: locality,
            City: city,
            State: Of("administrative_area_level_1"),
            PostalCode: Of("postal_code"));
    }

    // ---- Wire shapes: only what is read ---------------------------------------------------------

    private sealed class TextSearchResponse
    {
        [JsonPropertyName("places")] public List<GooglePlace>? Places { get; set; }
    }

    private sealed class GooglePlace
    {
        [JsonPropertyName("displayName")] public LocalizedText? DisplayName { get; set; }
        [JsonPropertyName("formattedAddress")] public string? FormattedAddress { get; set; }
        [JsonPropertyName("location")] public LatLngJson? Location { get; set; }
        [JsonPropertyName("addressComponents")] public List<PlaceComponent>? AddressComponents { get; set; }
    }

    private sealed class LocalizedText
    {
        [JsonPropertyName("text")] public string? Text { get; set; }
    }

    private sealed class LatLngJson
    {
        [JsonPropertyName("latitude")] public double Latitude { get; set; }
        [JsonPropertyName("longitude")] public double Longitude { get; set; }
    }

    private sealed class PlaceComponent
    {
        [JsonPropertyName("longText")] public string? LongText { get; set; }
        [JsonPropertyName("types")] public List<string>? Types { get; set; }
    }

    private sealed class GeocodeResponse
    {
        [JsonPropertyName("status")] public string? Status { get; set; }
        [JsonPropertyName("error_message")] public string? ErrorMessage { get; set; }
        [JsonPropertyName("results")] public List<GeocodeResult>? Results { get; set; }
    }

    private sealed class GeocodeResult
    {
        [JsonPropertyName("formatted_address")] public string? FormattedAddress { get; set; }
        [JsonPropertyName("address_components")] public List<GeocodeComponent>? AddressComponents { get; set; }
    }

    private sealed class GeocodeComponent
    {
        [JsonPropertyName("long_name")] public string? LongName { get; set; }
        [JsonPropertyName("types")] public List<string>? Types { get; set; }
    }
}
