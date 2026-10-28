namespace Zuno.Api.RateLimiting;

/// <summary>
/// The configured request limits, bound from the <c>RateLimiting</c> section.
/// </summary>
/// <remarks>
/// A zero or missing value means "not configured" and falls back to the real limit rather than to
/// zero. A misread setting must not silently become "no requests allowed", which would take the
/// whole API down more quietly than a crash would.
/// </remarks>
public sealed class RateLimitingOptions
{
    public const string SectionName = "RateLimiting";

    /// <summary>Every request, whatever the endpoint.</summary>
    public PolicyLimit Global { get; set; } = new();

    /// <summary>Sign-in, registration and the rest of the credential endpoints.</summary>
    public PolicyLimit Auth { get; set; } = new();

    /// <summary>The endpoint that calls out to a third-party geocoder on user-supplied text.</summary>
    public PolicyLimit PlaceSearch { get; set; } = new();

    /// <summary>Endpoints that take personal documents, such as a job application.</summary>
    public PolicyLimit DocumentUpload { get; set; } = new();

    /// <summary>How long each window lasts. Shared by every limit.</summary>
    public int WindowMinutes { get; set; }

    public sealed class PolicyLimit
    {
        public int PermitLimit { get; set; }
    }
}
