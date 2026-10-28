using System.ComponentModel.DataAnnotations;

namespace Zuno.Application.Common.Settings;

/// <summary>How often each instance re-reads the platform settings table.</summary>
public class PlatformSettingsOptions
{
    public const string SectionName = "PlatformSettings";

    /// <summary>
    /// The longest a changed rule takes to reach every instance. Short enough to feel immediate to an
    /// admin, long enough that the table is read a few times a minute, not on every request.
    /// </summary>
    [Range(5, 3600)]
    public int RefreshSeconds { get; set; } = 60;
}
