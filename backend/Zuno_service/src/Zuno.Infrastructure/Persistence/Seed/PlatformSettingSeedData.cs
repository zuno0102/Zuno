using Zuno.Application.Common.Settings;
using Zuno.Domain.Entities;

namespace Zuno.Infrastructure.Persistence.Seed;

/// <summary>
/// One row per rule, holding the value the code ships with. Built from the rule definitions rather than
/// typed out, so adding a rule to <see cref="PlatformRules"/> is the only step to seed it.
/// </summary>
public static class PlatformSettingSeedData
{
    private static readonly DateTimeOffset SeedDate = new(2026, 10, 28, 0, 0, 0, TimeSpan.Zero);

    public static PlatformSetting[] From(PlatformRules defaults) =>
    [
        .. PlatformRules.Definitions.Select(d => new PlatformSetting
        {
            // Stable per key, so re-generating migrations never churns the seed rows.
            Id = DeterministicGuid.From($"platform-setting:{d.Key}"),
            Key = d.Key,
            Value = d.Format(defaults),
            Description = d.Description,
            CreatedDate = SeedDate,
        }),
    ];
}
