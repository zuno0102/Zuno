using Zuno.Domain.Entities;
using Zuno.Domain.Enums;
using Zuno.Domain.ValueObjects;

namespace Zuno.Infrastructure.Persistence.Seed;

/// <summary>
/// The level ladders the code ships with, one row per rung. Built from
/// <see cref="LevelLadder.BusinessDefaults"/> and <see cref="LevelLadder.WorkerDefaults"/> so the seed
/// and the fallback can never disagree.
/// </summary>
public static class LevelDefinitionSeedData
{
    private static readonly DateTimeOffset SeedDate = new(2026, 10, 28, 0, 0, 0, TimeSpan.Zero);

    public static LevelDefinition[] Rows { get; } =
    [
        .. From(LevelAudience.Business, LevelLadder.BusinessDefaults),
        .. From(LevelAudience.Worker, LevelLadder.WorkerDefaults),
    ];

    private static IEnumerable<LevelDefinition> From(LevelAudience audience, LevelLadder ladder) =>
        ladder.Rungs.Select(r => new LevelDefinition
        {
            // Stable per rung, so re-generating migrations never churns the seed rows.
            Id = DeterministicGuid.From($"level-definition:{audience}:{r.Level}"),
            Audience = audience,
            Level = r.Level,
            Name = r.Name,
            MinCompletedJobs = r.MinCompletedJobs,
            MinRating = r.MinRating,
            MinBusinesses = r.MinBusinesses,
            MinAnsweredRate = r.MinAnsweredRate,
            CreatedDate = SeedDate,
        });
}
