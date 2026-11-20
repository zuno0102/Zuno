using System.ComponentModel.DataAnnotations;

namespace Zuno.Application.Common.Settings;

/// <summary>Where the Zuno Marketplace API lives, for a business's live posts when checking its plan.</summary>
public class MarketplaceApiSettings
{
    public const string SectionName = "MarketplaceApi";

    /// <summary>The Marketplace API's root address. Empty: Marketplace posts are not counted.</summary>
    public string BaseUrl { get; set; } = string.Empty;

    /// <summary>Long enough for a sleeping server on a free plan to wake.</summary>
    [Range(1, 300)]
    public int TimeoutSeconds { get; set; } = 60;

    public bool IsConfigured => !string.IsNullOrWhiteSpace(BaseUrl);
}

/// <summary>
/// The key the three Zuno APIs share for their calls to each other (counting and pausing a
/// business's listings). Never sent to an app; the same value is set on all three servers.
/// </summary>
public class InternalApiSettings
{
    public const string SectionName = "InternalApi";

    /// <summary>The header the key travels in.</summary>
    public const string HeaderName = "X-Zuno-Internal-Key";

    public string Key { get; set; } = string.Empty;

    public bool IsConfigured => !string.IsNullOrWhiteSpace(Key);
}
