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
/// <para>
/// The thresholds, names and small-sample rules are rows in the <c>level_definitions</c> and
/// <c>platform_settings</c> tables, passed in as a <see cref="LevelLadder"/>.
/// </para>
/// </remarks>
public static class WorkerLevel
{
    public const int Minimum = LevelLadder.Minimum;

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
        LevelLadder ladder,
        int completedJobCount,
        int businessesWorkedFor = 0,
        int offersDeclined = 0,
        decimal? ratingAverage = null,
        int ratingCount = 0)
    {
        foreach (var rung in ladder.Earned)
        {
            if (Meets(ladder, rung, completedJobCount, businessesWorkedFor, offersDeclined, ratingAverage, ratingCount))
            {
                return rung.Level;
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
        LevelLadder ladder,
        int completedJobCount,
        int businessesWorkedFor = 0,
        int offersDeclined = 0,
        decimal? ratingAverage = null,
        int ratingCount = 0)
    {
        var next = NextRung(ladder, completedJobCount, businessesWorkedFor, offersDeclined, ratingAverage, ratingCount);

        if (next is null)
        {
            return null;
        }

        var jobsShort = Math.Max(0, next.MinCompletedJobs - completedJobCount);
        var businessesShort = Math.Max(0, next.MinBusinesses - businessesWorkedFor);

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

        if (!MeetsAnsweredRate(ladder, completedJobCount, offersDeclined, next.MinAnsweredRate))
        {
            return "take more of the offers you are sent";
        }

        if (!MeetsRating(ladder, ratingAverage, ratingCount, next.MinRating))
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
        LevelLadder ladder,
        int completedJobCount,
        int businessesWorkedFor = 0,
        int offersDeclined = 0,
        decimal? ratingAverage = null,
        int ratingCount = 0)
    {
        var next = NextRung(ladder, completedJobCount, businessesWorkedFor, offersDeclined, ratingAverage, ratingCount);

        return next is null ? null : Math.Max(0, next.MinCompletedJobs - completedJobCount);
    }

    /// <summary>The rung above the one this record has earned, or null at the top.</summary>
    private static LevelRung? NextRung(
        LevelLadder ladder,
        int completedJobCount,
        int businessesWorkedFor,
        int offersDeclined,
        decimal? ratingAverage,
        int ratingCount) =>
        ladder.Rung(Calculate(
            ladder, completedJobCount, businessesWorkedFor, offersDeclined, ratingAverage, ratingCount) + 1);

    private static bool Meets(
        LevelLadder ladder,
        LevelRung rung,
        int completedJobCount,
        int businessesWorkedFor,
        int offersDeclined,
        decimal? ratingAverage,
        int ratingCount) =>
        completedJobCount >= rung.MinCompletedJobs
        && businessesWorkedFor >= rung.MinBusinesses
        && MeetsAnsweredRate(ladder, completedJobCount, offersDeclined, rung.MinAnsweredRate)
        && MeetsRating(ladder, ratingAverage, ratingCount, rung.MinRating);

    /// <summary>
    /// Whether enough of the offers this worker engaged with turned into finished work.
    /// </summary>
    /// <remarks>
    /// Turning down a job is a legitimate thing to do — the date did not suit, the pay was too low,
    /// the venue was too far. One decline out of two should not read as unreliable, so the rate is
    /// only applied once there is a pattern to read, for the same reason a thin review history is
    /// not: a bar that cannot be met yet is a bar that only punishes newcomers.
    /// </remarks>
    private static bool MeetsAnsweredRate(LevelLadder ladder, int completedJobCount, int offersDeclined, decimal required)
    {
        var offers = completedJobCount + offersDeclined;

        return offers == 0 || offers < ladder.MinimumOffersForRate || (decimal)completedJobCount / offers >= required;
    }

    /// <summary>
    /// Whether a rating clears the bar. Too few ratings to judge counts as clearing it — which, until
    /// businesses can rate workers at all, is every worker.
    /// </summary>
    private static bool MeetsRating(LevelLadder ladder, decimal? average, int ratingCount, decimal required) =>
        ratingCount < ladder.MinimumReviewsForAverage || (average ?? 0m) >= required;
}
