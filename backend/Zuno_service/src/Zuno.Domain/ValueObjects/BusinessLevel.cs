namespace Zuno.Domain.ValueObjects;

/// <summary>
/// A business's standing, from level 1 up, earned from jobs seen through to the last rupee and
/// how both sides rate them.
/// </summary>
/// <remarks>
/// Two rules give this its teeth.
///
/// A job counts only when the work is done <em>and</em> every worker is paid, so unpaid wages cost
/// the business credit for the whole job rather than nothing at all.
///
/// Both averages must clear the bar. A business cannot buy standing by delighting customers while
/// underpaying its crew — the worker average gates the level exactly as the customer one does.
/// An open dispute caps the level at 1 outright, however good the history. The thresholds and names
/// are rows in the <c>level_definitions</c> table, passed in as a <see cref="LevelLadder"/>.
/// </remarks>
public static class BusinessLevel
{
    public const int Minimum = LevelLadder.Minimum;

    /// <summary>
    /// Works out the level a business has earned.
    /// </summary>
    /// <param name="completedJobCount">Jobs both finished and fully settled.</param>
    /// <param name="customerRatingAverage">Null until there are any customer reviews.</param>
    /// <param name="workerRatingAverage">Null until there are any worker reviews.</param>
    /// <param name="openDisputeCount">Unresolved non-payment reports.</param>
    public static int Calculate(
        LevelLadder ladder,
        int completedJobCount,
        decimal? customerRatingAverage,
        int customerReviewCount,
        decimal? workerRatingAverage,
        int workerReviewCount,
        int openDisputeCount)
    {
        // An unanswered "I was never paid" outranks every other signal. Whatever the history, a
        // business with money owed to a worker is not one to recommend.
        if (openDisputeCount > 0)
        {
            return Minimum;
        }

        foreach (var rung in ladder.Earned)
        {
            if (completedJobCount >= rung.MinCompletedJobs
                && MeetsBar(ladder, customerRatingAverage, customerReviewCount, rung.MinRating)
                && MeetsBar(ladder, workerRatingAverage, workerReviewCount, rung.MinRating))
            {
                return rung.Level;
            }
        }

        return Minimum;
    }

    /// <summary>
    /// Whether one side's rating clears the bar. Too few reviews to judge counts as clearing it:
    /// a business with one glowing review has not proved itself, but neither should a thin record
    /// hold back someone whose job count has plainly been earned.
    /// </summary>
    private static bool MeetsBar(LevelLadder ladder, decimal? average, int reviewCount, decimal required) =>
        reviewCount < ladder.MinimumReviewsForAverage || (average ?? 0m) >= required;

}
