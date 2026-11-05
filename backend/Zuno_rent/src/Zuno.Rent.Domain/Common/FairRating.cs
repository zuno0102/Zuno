namespace Zuno.Rent.Domain.Common;

/// <summary>
/// A star average that a handful of ratings cannot swing: the real ratings are mixed with a few
/// imagined ones at an ordinary score, so one 5★ does not make a new item "5.0" and one 1★ does not
/// sink it. Three 5★ ratings read (15 + 4.0 × 5) / (3 + 5) = 4.4.
/// </summary>
/// <remarks>
/// The Service API rates businesses with the same numbers (PlatformRules <c>rating.*</c>), and it
/// combines Rent's totals with its own — keep the two in step.
/// </remarks>
public static class FairRating
{
    /// <summary>The score the imagined ratings give: an ordinary, good rental.</summary>
    public const decimal PriorAverage = 4.0m;

    /// <summary>How many imagined ratings are mixed in.</summary>
    public const int PriorWeight = 5;

    /// <summary>Fewer real ratings than this and no average is shown at all.</summary>
    public const int MinCount = 3;

    /// <summary>
    /// The fair average of <paramref name="count"/> ratings adding up to <paramref name="sum"/>, to one
    /// decimal place; null while there are fewer than <paramref name="minCount"/>.
    /// </summary>
    public static decimal? Of(
        decimal sum,
        int count,
        decimal priorAverage = PriorAverage,
        int priorWeight = PriorWeight,
        int minCount = MinCount) =>
        count >= minCount && count + priorWeight > 0
            ? Math.Round((sum + (priorAverage * priorWeight)) / (count + priorWeight), 1)
            : null;
}
