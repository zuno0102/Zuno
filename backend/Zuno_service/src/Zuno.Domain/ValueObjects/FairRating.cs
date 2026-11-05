namespace Zuno.Domain.ValueObjects;

/// <summary>
/// The one way every rating average in Zuno is worked out — for a service, for a business line and
/// for a business overall.
/// </summary>
/// <remarks>
/// A plain mean lets one five-star review put a brand-new business above one with a hundred honest
/// fours. So every average starts from a few imaginary "typical" ratings (the prior) and real ratings
/// pull it away from there: with few ratings the result stays near the typical value, with many it is
/// almost exactly the real mean. Below a minimum number of ratings there is no average at all, which
/// the app shows as "not rated yet" rather than a misleading number. The prior and the minimum are
/// platform settings; the Rent API uses the same numbers so a business reads the same everywhere.
/// </remarks>
public static class FairRating
{
    /// <summary>Places the result is rounded to — one, as the stars are shown ("4.4").</summary>
    public const int Decimals = 1;

    /// <summary>
    /// The fair average of <paramref name="count"/> ratings adding up to <paramref name="sum"/>, or
    /// null when there are fewer than <paramref name="minCount"/> of them.
    /// </summary>
    /// <param name="sum">All the stars given, added together.</param>
    /// <param name="count">How many ratings there are.</param>
    /// <param name="priorAverage">The typical rating every average starts from, e.g. 4.0.</param>
    /// <param name="priorWeight">How many imaginary typical ratings it starts with, e.g. 5.</param>
    /// <param name="minCount">Fewest ratings before an average is shown at all.</param>
    public static decimal? Of(decimal sum, int count, decimal priorAverage, int priorWeight, int minCount)
    {
        if (count <= 0 || count < minCount)
        {
            return null;
        }

        var weight = Math.Max(priorWeight, 0);
        return Math.Round(
            (sum + (priorAverage * weight)) / (count + weight),
            Decimals);
    }
}

/// <summary>The settings a fair average is worked out with — see <see cref="FairRating"/>.</summary>
/// <param name="Average">The typical rating every average starts from.</param>
/// <param name="Weight">How many imaginary typical ratings it starts with.</param>
/// <param name="MinCount">Fewest ratings before an average is shown at all.</param>
public sealed record RatingPrior(decimal Average, int Weight, int MinCount);
