namespace Zuno.Domain.ValueObjects;

/// <summary>Where a business stands on its ladder, and the two dates that decide its next move.</summary>
/// <param name="Level">The level shown on its badge.</param>
/// <param name="LevelSince">When it reached that level. Null for a level held since before this was recorded.</param>
/// <param name="BelowSince">When it first stopped meeting that level's rules. Null while it meets them.</param>
public sealed record LevelPosition(int Level, DateTimeOffset? LevelSince, DateTimeOffset? BelowSince);

/// <summary>How quickly a stored level may follow the level a business has earned.</summary>
/// <param name="MinTimeAtLevel">Least time at one level before the next step up.</param>
/// <param name="DropGrace">How long a business may sit below its level's rules before it steps down.</param>
public sealed record LevelPace(TimeSpan MinTimeAtLevel, TimeSpan DropGrace);
