namespace Zuno.Domain.ValueObjects;

/// <summary>
/// A worker's standing, 1–5, earned from their whole record rather than a job count alone.
/// </summary>
/// <remarks>
/// <para>
/// It used to be jobs and nothing else, so five jobs for one business — taken and finished with half
/// the offers ignored — read exactly like five jobs for five businesses with every offer answered.
/// A level that counts only volume says nothing about whether a business should hire somebody.
/// </para>
/// <para>
/// Three things now have to hold together for a level, and each is something the worker controls:
/// </para>
/// <list type="bullet">
///   <item><b>Work finished</b> — jobs seen through to the end, as before.</item>
///   <item><b>Businesses who hired them</b> — breadth. One business hiring somebody twenty times is
///   one business's opinion; five businesses is a record.</item>
///   <item><b>Offers answered</b> — of the offers they engaged with, how many became finished work.
///   Judged only once there are enough to judge, so one decline early on cannot hold anybody back.</item>
/// </list>
/// <para>
/// <b>What is deliberately not in here.</b>
/// </para>
/// <list type="bullet">
///   <item><b>Open disputes do not cap a worker's level</b>, the opposite of the business rule. A
///   dispute is a worker reporting that money never arrived; penalising them for raising it would
///   punish the person the protection exists for, and would teach workers to stay quiet about unpaid
///   wages.</item>
///   <item><b>Wages received</b> is not a signal either. Whether a wage arrives is the business's
///   doing, and a worker whose employer pays late would otherwise be marked down for it.</item>
///   <item><b>ID verification</b> is not a gate, though it reads like an obvious one: nothing in the
///   app sets a worker's verification to Verified — there is no admin flow for it — so gating on it
///   would freeze every worker in existence below level 3 for ever.</item>
/// </list>
/// <para>
/// <b>Ratings.</b> The bar is in the table and currently always passes, because no business can rate
/// a worker yet: that is a two-sided-review feature nobody has built. Written in now so the rule says
/// what it intends, and so wiring it up later is one call site rather than a redesign. The level
/// names still describe experience, never quality, because experience is all the data supports.
/// </para>
/// </remarks>
public static class WorkerLevel
{
    public const int Minimum = 1;
    public const int Maximum = 5;

    /// <summary>Ratings needed before an average is treated as meaningful rather than noise.</summary>
    public const int MinimumReviewsForAverage = 3;

    /// <summary>
    /// Offers needed before the answered-offers rate is judged at all.
    /// </summary>
    /// <remarks>
    /// Turning down a job is a legitimate thing to do — the date did not suit, the pay was too low,
    /// the venue was too far. One decline out of two should not read as unreliable, so the rate is
    /// only applied once there is a pattern to read.
    /// </remarks>
    public const int MinimumOffersForRate = 5;

    /// <summary>
    /// What each level asks for: finished jobs, distinct businesses, answered-offer rate, rating.
    /// Highest first, so the first row that holds is the level.
    /// </summary>
    private static readonly (int Level, int Jobs, int Businesses, double AnsweredRate, decimal Rating)[] Thresholds =
    [
        (5, 100, 8, 0.90, 4.5m),
        (4, 50, 5, 0.85, 4.3m),
        (3, 20, 3, 0.80, 4.0m),
        (2, 5, 1, 0.70, 3.5m),
    ];

    /// <summary>
    /// What to call a level on a badge.
    /// </summary>
    /// <remarks>
    /// Every name describes how much work somebody has done, not how well they did it. "Trusted" or
    /// "Top rated" would imply a judgement nobody has made — no business can rate a worker yet.
    /// </remarks>
    public static string Name(int level) => level switch
    {
        5 => "Highly experienced",
        4 => "Very experienced",
        3 => "Experienced",
        2 => "Getting established",
        _ => "New",
    };

    /// <summary>The level this record has earned.</summary>
    /// <param name="completedJobCount">
    /// Jobs whose work is done, by either route onto them. Counted once each — see
    /// <c>WorkerEarningsRollup</c> for why that needs care.
    /// </param>
    /// <param name="businessesWorkedFor">Distinct businesses that have hired them.</param>
    /// <param name="offersDeclined">Offers turned down. Post route only — the only route that has them.</param>
    /// <param name="ratingAverage">Null until businesses can rate workers, which is not yet.</param>
    /// <param name="ratingCount">How many ratings that average rests on.</param>
    public static int Calculate(
        int completedJobCount,
        int businessesWorkedFor = 0,
        int offersDeclined = 0,
        decimal? ratingAverage = null,
        int ratingCount = 0)
    {
        foreach (var (level, jobs, businesses, answeredRate, rating) in Thresholds)
        {
            if (completedJobCount >= jobs
                && businessesWorkedFor >= businesses
                && MeetsAnsweredRate(completedJobCount, offersDeclined, answeredRate)
                && MeetsRating(ratingAverage, ratingCount, rating))
            {
                return level;
            }
        }

        return Minimum;
    }

    /// <summary>
    /// What stands between this worker and the next level, in their own terms.
    /// </summary>
    /// <remarks>
    /// One sentence naming the nearest thing to fix, because a level is only worth showing if it
    /// reads as reachable. It used to be a bare job count, which became a lie the moment the level
    /// depended on anything else: a worker with thirty jobs for one business would have been told
    /// "0 jobs to level 3" and left to guess.
    ///
    /// Jobs are named first when both are short, since finishing work is the thing a worker can go
    /// and do today — who hires them follows from it.
    /// </remarks>
    public static string? NextLevelRequirement(
        int completedJobCount,
        int businessesWorkedFor = 0,
        int offersDeclined = 0,
        decimal? ratingAverage = null,
        int ratingCount = 0)
    {
        var current = Calculate(
            completedJobCount, businessesWorkedFor, offersDeclined, ratingAverage, ratingCount);

        if (current >= Maximum)
        {
            return null;
        }

        var next = Thresholds.FirstOrDefault(t => t.Level == current + 1);

        if (next.Level == 0)
        {
            return null;
        }

        var jobsShort = Math.Max(0, next.Jobs - completedJobCount);
        var businessesShort = Math.Max(0, next.Businesses - businessesWorkedFor);

        if (jobsShort > 0)
        {
            return jobsShort == 1 ? "1 more job" : $"{jobsShort} more jobs";
        }

        if (businessesShort > 0)
        {
            return businessesShort == 1
                ? "work for 1 more business"
                : $"work for {businessesShort} more businesses";
        }

        if (!MeetsAnsweredRate(completedJobCount, offersDeclined, next.AnsweredRate))
        {
            return "take more of the offers you are sent";
        }

        if (!MeetsRating(ratingAverage, ratingCount, next.Rating))
        {
            return "a higher rating from the businesses you work for";
        }

        return null;
    }

    /// <summary>How many more jobs until the next level, or null at the top.</summary>
    /// <remarks>
    /// Kept because the number is still the most useful single figure, and because it is what the
    /// app has always shown. It answers only the jobs half — [NextLevelRequirement] is what says
    /// whether jobs are actually the thing in the way.
    /// </remarks>
    public static int? JobsToNextLevel(
        int completedJobCount,
        int businessesWorkedFor = 0,
        int offersDeclined = 0,
        decimal? ratingAverage = null,
        int ratingCount = 0)
    {
        var current = Calculate(
            completedJobCount, businessesWorkedFor, offersDeclined, ratingAverage, ratingCount);

        if (current >= Maximum)
        {
            return null;
        }

        var next = Thresholds
            .Where(threshold => threshold.Level == current + 1)
            .Select(threshold => threshold.Jobs)
            .FirstOrDefault();

        return next == 0 ? null : Math.Max(0, next - completedJobCount);
    }

    /// <summary>
    /// Whether enough of the offers this worker engaged with turned into finished work.
    /// </summary>
    /// <remarks>
    /// Too few offers to judge counts as clearing it, for the same reason a thin review history does:
    /// a bar that cannot be met yet is a bar that only punishes newcomers.
    /// </remarks>
    private static bool MeetsAnsweredRate(int completedJobCount, int offersDeclined, double required)
    {
        var offers = completedJobCount + offersDeclined;

        return offers < MinimumOffersForRate || (double)completedJobCount / offers >= required;
    }

    /// <summary>
    /// Whether a rating clears the bar. Too few ratings to judge counts as clearing it — which, until
    /// businesses can rate workers at all, is every worker.
    /// </summary>
    private static bool MeetsRating(decimal? average, int ratingCount, decimal required) =>
        ratingCount < MinimumReviewsForAverage || (average ?? 0m) >= required;
}
