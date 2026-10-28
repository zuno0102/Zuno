namespace Zuno.Domain.ValueObjects;

/// <summary>What one level asks for, and what it is called on a badge.</summary>
/// <param name="Level">1 is where everybody starts; its thresholds are ignored.</param>
/// <param name="MinBusinesses">Distinct businesses that hired them. Workers only.</param>
/// <param name="MinAnsweredRate">Share of offers turned into finished work, 0–1. Workers only.</param>
public sealed record LevelRung(
    int Level,
    string Name,
    int MinCompletedJobs,
    decimal MinRating,
    int MinBusinesses = 0,
    decimal MinAnsweredRate = 0m);

/// <summary>
/// The levels one kind of account can reach: the rungs and the small-sample rules that go with them.
/// Read from the <c>level_definitions</c> table; the defaults below are what it is seeded with.
/// </summary>
/// <param name="Rungs">One per level, numbered 1 upwards without gaps.</param>
/// <param name="MinimumReviewsForAverage">Reviews needed before an average is judged at all.</param>
/// <param name="MinimumOffersForRate">Offers needed before the answered-offers rate is judged. Workers only.</param>
public sealed record LevelLadder(
    IReadOnlyList<LevelRung> Rungs,
    int MinimumReviewsForAverage,
    int MinimumOffersForRate = 0)
{
    public const int Minimum = 1;

    /// <summary>Most levels a ladder may have, so a badge and its colours stay finite.</summary>
    public const int MostLevels = 10;

    public int Maximum => Rungs.Count == 0 ? Minimum : Rungs.Max(r => r.Level);

    /// <summary>The rungs above the first, highest first — the order a level is found in.</summary>
    public IEnumerable<LevelRung> Earned => Rungs.Where(r => r.Level > Minimum).OrderByDescending(r => r.Level);

    public LevelRung? Rung(int level) => Rungs.FirstOrDefault(r => r.Level == level);

    /// <summary>What to call a level on a badge. Anything unknown reads as the first level.</summary>
    public string Name(int level) => (Rung(level) ?? Rung(Minimum))?.Name ?? string.Empty;

    /// <summary>
    /// Why these rungs cannot be used, or null when they can: levels 1..n without gaps, every rung
    /// named, values in range, and no level asking for less than the one below it.
    /// </summary>
    public static string? Problem(IReadOnlyList<LevelRung> rungs)
    {
        if (rungs.Count == 0 || rungs.Count > MostLevels)
        {
            return $"needs between 1 and {MostLevels} levels";
        }

        var ordered = rungs.OrderBy(r => r.Level).ToList();
        for (var i = 0; i < ordered.Count; i++)
        {
            var rung = ordered[i];
            if (rung.Level != i + 1)
            {
                return "levels must run 1, 2, 3… without gaps or repeats";
            }

            if (string.IsNullOrWhiteSpace(rung.Name))
            {
                return $"level {rung.Level} has no name";
            }

            if (rung.MinCompletedJobs < 0 || rung.MinBusinesses < 0
                || rung.MinRating is < 0m or > 5m
                || rung.MinAnsweredRate is < 0m or > 1m)
            {
                return $"level {rung.Level} has a value out of range";
            }

            // Level 1's thresholds are never read, so the climb is checked from level 3 down to 2.
            if (i > 1)
            {
                var below = ordered[i - 1];
                if (rung.MinCompletedJobs < below.MinCompletedJobs
                    || rung.MinBusinesses < below.MinBusinesses
                    || rung.MinRating < below.MinRating
                    || rung.MinAnsweredRate < below.MinAnsweredRate)
                {
                    return $"level {rung.Level} asks for less than level {below.Level}";
                }
            }
        }

        return null;
    }

    /// <summary>The business levels the code ships with.</summary>
    public static LevelLadder BusinessDefaults { get; } = new(
    [
        new(1, "New", 0, 0m),
        new(2, "Rising", 5, 3.5m),
        new(3, "Trusted", 20, 4.0m),
        new(4, "Established", 50, 4.3m),
        new(5, "Top rated", 100, 4.5m),
    ],
    MinimumReviewsForAverage: 3);

    /// <summary>
    /// The worker levels the code ships with. Every name describes how much work somebody has done,
    /// not how well — no business can rate a worker yet, so a quality word would claim a judgement
    /// nobody has made.
    /// </summary>
    public static LevelLadder WorkerDefaults { get; } = new(
    [
        new(1, "New", 0, 0m),
        new(2, "Getting established", 5, 3.5m, MinBusinesses: 1, MinAnsweredRate: 0.70m),
        new(3, "Experienced", 20, 4.0m, MinBusinesses: 3, MinAnsweredRate: 0.80m),
        new(4, "Very experienced", 50, 4.3m, MinBusinesses: 5, MinAnsweredRate: 0.85m),
        new(5, "Highly experienced", 100, 4.5m, MinBusinesses: 8, MinAnsweredRate: 0.90m),
    ],
    MinimumReviewsForAverage: 3,
    MinimumOffersForRate: 5);
}
