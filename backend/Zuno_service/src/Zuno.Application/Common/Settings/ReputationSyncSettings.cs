using System.ComponentModel.DataAnnotations;

namespace Zuno.Application.Common.Settings;

/// <summary>How the periodic standing refresh works through the businesses. How often it runs is the
/// <c>reputation.sync-minutes</c> platform setting.</summary>
public class ReputationSyncSettings
{
    public const string SectionName = "ReputationSync";

    /// <summary>Businesses loaded, recalculated and saved together, so one pass never holds them all.</summary>
    [Range(1, 5000)]
    public int BatchSize { get; set; } = 500;
}
