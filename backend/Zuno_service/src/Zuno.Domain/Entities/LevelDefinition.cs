using Zuno.Domain.Common;
using Zuno.Domain.Enums;

namespace Zuno.Domain.Entities;

/// <summary>
/// One rung of a business or worker level ladder: what it asks for and what its badge says.
/// </summary>
/// <remarks>
/// Read through the platform settings store, which checks the whole ladder before using it — levels
/// 1..n without gaps, every rung named, no rung asking for less than the one below — and keeps the
/// built-in ladder for any audience whose rows fail. A bad edit can therefore never leave nobody able
/// to level up, or two badges for one level.
/// </remarks>
public class LevelDefinition : BaseEntity
{
    public LevelAudience Audience { get; set; }

    public int Level { get; set; }

    public string Name { get; set; } = string.Empty;

    public int MinCompletedJobs { get; set; }

    /// <summary>Lowest average rating, 0–5, both sides must hold once they have enough reviews.</summary>
    public decimal MinRating { get; set; }

    /// <summary>Distinct businesses that hired them. Workers only.</summary>
    public int MinBusinesses { get; set; }

    /// <summary>Share of offers that became finished work, 0–1. Workers only.</summary>
    public decimal MinAnsweredRate { get; set; }
}
