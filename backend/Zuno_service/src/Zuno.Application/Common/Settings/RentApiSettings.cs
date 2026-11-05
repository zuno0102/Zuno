using System.ComponentModel.DataAnnotations;

namespace Zuno.Application.Common.Settings;

/// <summary>Where the Zuno Rent API lives, for reading each business's Rent record.</summary>
public class RentApiSettings
{
    public const string SectionName = "RentApi";

    /// <summary>The Rent API's root address. Empty switches the Rent figures off; levels still refresh.</summary>
    public string BaseUrl { get; set; } = string.Empty;

    /// <summary>
    /// How long to wait for an answer, in seconds. Long on purpose: a Rent API on a free plan can take
    /// most of a minute to wake up, and this call runs in the background where nobody is waiting.
    /// </summary>
    [Range(1, 300)]
    public int TimeoutSeconds { get; set; } = 60;

    public bool IsConfigured => !string.IsNullOrWhiteSpace(BaseUrl);
}
