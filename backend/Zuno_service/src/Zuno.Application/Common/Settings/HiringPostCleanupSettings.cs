using System.ComponentModel.DataAnnotations;

namespace Zuno.Application.Common.Settings;

/// <summary>How often, and how much at a time, unfilled past hiring posts are cleared away.</summary>
public class HiringPostCleanupSettings
{
    public const string SectionName = "HiringPostCleanup";

    [Range(1, 1440)]
    public int IntervalMinutes { get; set; } = 15;

    [Range(1, 5000)]
    public int BatchSize { get; set; } = 500;
}
