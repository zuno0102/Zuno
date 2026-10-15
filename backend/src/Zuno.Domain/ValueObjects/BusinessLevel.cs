namespace Zuno.Domain.ValueObjects;

/// <summary>
/// A business's standing, 1–5, earned from jobs seen through to the last rupee and how both sides
/// rate them.
/// </summary>
/// <remarks>
/// Two rules give this its teeth.
///
/// A job counts only when the work is done <em>and</em> every worker is paid, so unpaid wages cost
/// the business credit for the whole job rather than nothing at all.
///
/// Both averages must clear the bar. A business cannot buy standing by delighting customers while
/// underpaying its crew — the worker average gates the level exactly as the customer one does.
/// An open dispute caps the level at 1 outright, however good the history.
/// </remarks>
public static class BusinessLevel
{
    public const int Minimum = 1;
    public const int Maximum = 5;

    /// <summary>Reviews needed before an average is treated as meaningful rather than noise.</summary>
    public const int MinimumReviewsForAverage = 3;

    private static readonly (int Level, int Jobs, decimal Rating)[] Thresholds =
    [
        (5, 100, 4.5m),
        (4, 50, 4.3m),
        (3, 20, 4.0m),
        (2, 5, 3.5m),
    ];

    /// <summary>Human-readable name for a level, for badges and profile headers.</summary>
    public static string Name(int level) => level switch
    {
        5 => "Top rated",
        4 => "Established",
        3 => "Trusted",
        2 => "Rising",
        _ => "New",
    };

    /// <summary>
    /// Works out the level a business has earned.
    /// </summary>
    /// <param name="completedJobCount">Jobs both finished and fully settled.</param>
    /// <param name="customerRatingAverage">Null until there are any customer reviews.</param>
    /// <param name="workerRatingAverage">Null until there are any worker reviews.</param>
    /// <param name="openDisputeCount">Unresolved non-payment reports.</param>
    public static int Calculate(
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

        foreach (var (level, jobs, rating) in Thresholds)
        {
            if (completedJobCount >= jobs
                && MeetsBar(customerRatingAverage, customerReviewCount, rating)
                && MeetsBar(workerRatingAverage, workerReviewCount, rating))
            {
                return level;
            }
        }

        return Minimum;
    }

    /// <summary>
    /// Whether one side's rating clears the bar. Too few reviews to judge counts as clearing it:
    /// a business with one glowing review has not proved itself, but neither should a thin record
    /// hold back someone whose job count has plainly been earned.
    /// </summary>
    private static bool MeetsBar(decimal? average, int reviewCount, decimal required) =>
        reviewCount < MinimumReviewsForAverage || (average ?? 0m) >= required;

}
