namespace Zuno.Application.Common.Interfaces;

/// <summary>
/// Turning a typed place name into a point on the map.
/// </summary>
/// <remarks>
/// An interface because the provider behind it is expected to change. It starts on OpenStreetMap,
/// which is free and needs no key, and can become Google Places later without any caller knowing.
/// </remarks>
public interface IPlaceSearchService
{
    /// <summary>
    /// Places matching what the user typed, best match first. Empty when nothing matched.
    /// </summary>
    /// <remarks>
    /// Search-on-submit, never as-you-type. OpenStreetMap's terms cap use at roughly one request a
    /// second and explicitly ask clients not to drive autocomplete, so a keystroke-per-request design
    /// would get the server blocked.
    /// </remarks>
    Task<IReadOnlyList<PlaceResult>> SearchAsync(
        string query,
        CancellationToken cancellationToken = default);

    /// <summary>
    /// The name of the place at these coordinates, or null if it cannot be named.
    /// </summary>
    /// <remarks>
    /// So a worker who shares their location sees where the app thinks they are — "Kazhakoottam"
    /// rather than "your current location". A position nobody can read is a position nobody can
    /// check, and a GPS fix that landed in the wrong district should be obvious at a glance.
    /// </remarks>
    /// <param name="precise">
    /// Street level rather than suburb level. Used when somebody pins the exact house for a job, so
    /// the address fields can be filled from the pin; a worker naming their area keeps the default.
    /// </param>
    Task<PlaceResult?> ReverseAsync(
        double latitude,
        double longitude,
        bool precise = false,
        CancellationToken cancellationToken = default);
}

/// <summary>One place somebody could be, or hold an event at.</summary>
/// <param name="Name">The short name, e.g. "Kazhakoottam".</param>
/// <param name="FullName">The whole address as the provider returned it, for telling two alike apart.</param>
/// <param name="Latitude">Degrees north.</param>
/// <param name="Longitude">Degrees east.</param>
/// <param name="Street">Road name, when the provider knows it.</param>
/// <param name="Locality">Suburb, neighbourhood or village inside the city.</param>
/// <param name="City">City, town or village.</param>
/// <param name="State">State, e.g. "Tamil Nadu".</param>
/// <param name="PostalCode">PIN code.</param>
public record PlaceResult(
    string Name,
    string FullName,
    double Latitude,
    double Longitude,
    string? Street = null,
    string? Locality = null,
    string? City = null,
    string? State = null,
    string? PostalCode = null);
