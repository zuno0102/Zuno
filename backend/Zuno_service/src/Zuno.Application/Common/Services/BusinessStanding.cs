using Zuno.Application.Common.Settings;
using Zuno.Domain.Entities;
using Zuno.Domain.ValueObjects;

namespace Zuno.Application.Common.Services;

/// <summary>
/// Turns a business's raw counts — jobs, ratings per line, disputes — into the figures customers see:
/// its overall rating and its level. Pure, so every rule can be tested without a database.
/// </summary>
public static class BusinessStanding
{
    /// <summary>
    /// Works out the overall rating and moves the level one step towards what the record earns. The
    /// counts on <paramref name="profile"/> must already be current.
    /// </summary>
    public static void Apply(BusinessOwnerProfile profile, PlatformRules rules, DateTimeOffset now)
    {
        // One overall number across every line, so a business good at both Service and Rent is judged
        // on everything it has done rather than on whichever line happens to be shown.
        profile.CustomerReviewCount = profile.ServiceRatingCount + profile.RentRatingCount;
        profile.CustomerRatingAverage = rules.FairRating(
            profile.ServiceRatingSum + profile.RentRatingSum,
            profile.CustomerReviewCount);

        var earned = BusinessLevel.Calculate(
            rules.BusinessLevels,
            profile.TotalSuccessfulJobs,
            profile.CustomerRatingAverage,
            profile.CustomerReviewCount,
            profile.WorkerRatingAverage,
            profile.WorkerReviewCount,
            profile.OpenDisputeCount);

        if (profile.OpenDisputeCount > 0)
        {
            // Unchanged from before levels moved gradually: money owed to a worker drops the badge to
            // the first level at once. Climbing back is gradual, from the moment of the drop.
            if (profile.Level != earned)
            {
                profile.Level = earned;
                profile.LevelSince = now;
            }

            profile.LevelBelowSince = null;
        }
        else
        {
            var moved = BusinessLevel.Move(
                new LevelPosition(profile.Level, profile.LevelSince, profile.LevelBelowSince),
                earned,
                now,
                rules.BusinessLevelPace);

            profile.Level = moved.Level;
            profile.LevelSince = moved.LevelSince;
            profile.LevelBelowSince = moved.BelowSince;
        }

        profile.LevelRecalculatedAt = now;
    }

    /// <summary>The per-line ratings a customer or the owner sees, each worked out the fair way.</summary>
    public static LineRatings Lines(BusinessOwnerProfile profile, PlatformRules rules) => new(
        rules.FairRating(profile.ServiceRatingSum, profile.ServiceRatingCount),
        profile.ServiceRatingCount,
        rules.FairRating(profile.RentRatingSum, profile.RentRatingCount),
        profile.RentRatingCount);
}

/// <summary>A business's rating on each line it runs. An average is null until that line has enough ratings.</summary>
public sealed record LineRatings(
    decimal? ServiceRatingAverage,
    int ServiceRatingCount,
    decimal? RentRatingAverage,
    int RentRatingCount);
