using FluentAssertions;
using Zuno.Application.Common.Services;
using Zuno.Application.Common.Settings;
using Zuno.Domain.Entities;

namespace Zuno.Application.UnitTests.Common.Reputation;

/// <summary>
/// One business, several lines: the overall rating and the level count Service and Rent together.
/// </summary>
public class BusinessStandingTests
{
    private static readonly DateTimeOffset Now = new(2026, 11, 5, 10, 0, 0, TimeSpan.Zero);
    private static readonly PlatformRules Rules = PlatformRules.Defaults;

    [Fact]
    public void ServiceAndRent_AddUpToOneOverallRating()
    {
        var profile = new BusinessOwnerProfile
        {
            ServiceRatingSum = 10m, ServiceRatingCount = 2,
            RentRatingSum = 15m, RentRatingCount = 3,
        };

        BusinessStanding.Apply(profile, Rules, Now);

        profile.CustomerReviewCount.Should().Be(5);
        profile.CustomerRatingAverage.Should().Be(4.5m); // (25 + 20) / 10
    }

    [Fact]
    public void EachLine_IsRatedOnItsOwn_AndHiddenUnderTheMinimum()
    {
        var profile = new BusinessOwnerProfile
        {
            ServiceRatingSum = 10m, ServiceRatingCount = 2,
            RentRatingSum = 15m, RentRatingCount = 3,
        };

        BusinessStanding.Lines(profile, Rules).Should().Be(new LineRatings(null, 2, 4.4m, 3));
    }

    [Fact]
    public void FewerThanThreeRatingsOverall_ShowNoAverage()
    {
        var profile = new BusinessOwnerProfile { ServiceRatingSum = 5m, ServiceRatingCount = 1, RentRatingSum = 5m, RentRatingCount = 1 };

        BusinessStanding.Apply(profile, Rules, Now);

        profile.CustomerReviewCount.Should().Be(2);
        profile.CustomerRatingAverage.Should().BeNull();
    }

    [Fact]
    public void RentOrders_CountTowardsTheLevel()
    {
        // 3 Service jobs alone earn nothing; with 2 Rent orders the business has the 5 that Rising needs.
        var profile = new BusinessOwnerProfile { CompletedJobCount = 3, RentSuccessfulOrders = 2 };

        BusinessStanding.Apply(profile, Rules, Now);

        profile.TotalSuccessfulJobs.Should().Be(5);
        profile.Level.Should().Be(2);
        profile.LevelSince.Should().Be(Now);
        profile.LevelRecalculatedAt.Should().Be(Now);
    }

    [Fact]
    public void ALowCombinedRating_HoldsTheLevelBack()
    {
        // 20 jobs would be Trusted (4.0), but ten Rent ratings averaging 3.6 make the overall 3.7.
        var profile = new BusinessOwnerProfile
        {
            Level = 2, LevelSince = Now.AddDays(-30),
            CompletedJobCount = 20, RentRatingSum = 36m, RentRatingCount = 10,
        };

        BusinessStanding.Apply(profile, Rules, Now);

        profile.CustomerRatingAverage.Should().Be(3.7m);
        profile.Level.Should().Be(2);
        profile.LevelBelowSince.Should().BeNull();
    }

    [Fact]
    public void ManyLevelsEarned_StillClimbsOneAtATime()
    {
        var profile = new BusinessOwnerProfile { Level = 1, CompletedJobCount = 100, RentSuccessfulOrders = 50 };

        BusinessStanding.Apply(profile, Rules, Now);
        profile.Level.Should().Be(2);

        BusinessStanding.Apply(profile, Rules, Now.AddDays(1));
        profile.Level.Should().Be(2);

        BusinessStanding.Apply(profile, Rules, Now.AddDays(14));
        profile.Level.Should().Be(3);
    }

    [Fact]
    public void AnOpenDispute_StillDropsToLevelOne_AtOnce()
    {
        var profile = new BusinessOwnerProfile
        {
            Level = 4, LevelSince = Now.AddDays(-100), LevelBelowSince = Now.AddDays(-1),
            CompletedJobCount = 60, OpenDisputeCount = 1,
        };

        BusinessStanding.Apply(profile, Rules, Now);

        profile.Level.Should().Be(1);
        profile.LevelSince.Should().Be(Now);
        profile.LevelBelowSince.Should().BeNull();
    }

    [Fact]
    public void FallingShort_DropsOneLevel_OnlyAfterTheGrace()
    {
        var profile = new BusinessOwnerProfile { Level = 3, LevelSince = Now.AddDays(-60), CompletedJobCount = 6 };

        BusinessStanding.Apply(profile, Rules, Now);
        profile.Level.Should().Be(3);
        profile.LevelBelowSince.Should().Be(Now);

        BusinessStanding.Apply(profile, Rules, Now.AddDays(7));
        profile.Level.Should().Be(2);
        profile.LevelBelowSince.Should().BeNull();
    }
}
