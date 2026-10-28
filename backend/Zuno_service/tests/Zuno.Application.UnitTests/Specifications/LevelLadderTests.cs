using FluentAssertions;
using Zuno.Application.Common.Settings;
using Zuno.Domain.Enums;
using Zuno.Domain.ValueObjects;

namespace Zuno.Application.UnitTests.Specifications;

/// <summary>
/// Level thresholds and names come from the level_definitions table. A good ladder changes the level;
/// a bad one can never leave nobody able to level up.
/// </summary>
public class LevelLadderTests
{
    private static readonly LevelLadder Business = LevelLadder.BusinessDefaults;

    private static int BusinessLevelOf(
        LevelLadder ladder, int jobs, decimal? customerAverage = null, int customerReviews = 0,
        decimal? workerAverage = null, int workerReviews = 0, int disputes = 0) =>
        BusinessLevel.Calculate(ladder, jobs, customerAverage, customerReviews, workerAverage, workerReviews, disputes);

    // ---- The shipped business ladder behaves as the code did before it was a table -------------

    [Theory]
    [InlineData(0, 1)]
    [InlineData(4, 1)]
    [InlineData(5, 2)]
    [InlineData(19, 2)]
    [InlineData(20, 3)]
    [InlineData(50, 4)]
    [InlineData(100, 5)]
    [InlineData(10_000, 5)]
    public void Business_JobsAlone_ClimbTheDefaultLadder(int jobs, int expected) =>
        BusinessLevelOf(Business, jobs).Should().Be(expected);

    [Fact]
    public void Business_AnOpenDispute_CapsTheLevelAtOne() =>
        BusinessLevelOf(Business, 500, 5m, 50, 5m, 50, disputes: 1).Should().Be(1);

    [Fact]
    public void Business_ALowWorkerAverage_HoldsTheLevelBack_EvenWithHappyCustomers() =>
        BusinessLevelOf(Business, 100, 4.9m, 30, workerAverage: 4.1m, workerReviews: 10).Should().Be(3);

    [Fact]
    public void Business_TooFewReviewsToJudge_DoNotHoldTheLevelBack() =>
        BusinessLevelOf(Business, 100, customerAverage: 1m, customerReviews: 2).Should().Be(5);

    [Theory]
    [InlineData(1, "New")]
    [InlineData(3, "Trusted")]
    [InlineData(5, "Top rated")]
    [InlineData(0, "New")]     // unknown reads as the first level
    [InlineData(99, "New")]
    public void Business_Names_ComeFromTheLadder(int level, string expected) =>
        Business.Name(level).Should().Be(expected);

    // ---- The ladder follows the table, not a literal -----------------------------------------

    [Fact]
    public void ACustomLadder_ChangesThresholdsNamesAndTheTop()
    {
        var ladder = Business with
        {
            Rungs =
            [
                new(1, "Starter", 0, 0m),
                new(2, "Pro", 2, 0m),
                new(3, "Elite", 4, 0m),
            ],
        };

        BusinessLevelOf(ladder, 1).Should().Be(1);
        BusinessLevelOf(ladder, 2).Should().Be(2);
        BusinessLevelOf(ladder, 1000).Should().Be(3);
        ladder.Maximum.Should().Be(3);
        ladder.Name(3).Should().Be("Elite");
    }

    [Fact]
    public void TheReviewMinimum_FollowsTheSetting()
    {
        // Two poor reviews: ignored at the default minimum of 3, judged at a minimum of 2.
        BusinessLevelOf(Business, 100, 2m, 2).Should().Be(5);
        BusinessLevelOf(Business with { MinimumReviewsForAverage = 2 }, 100, 2m, 2).Should().Be(1);
    }

    [Fact]
    public void TheOffersMinimum_FollowsTheSetting()
    {
        var worker = LevelLadder.WorkerDefaults;

        // 5 jobs, 5 declines: a 50% rate. Ten offers is judged by default; not when 20 are needed.
        WorkerLevel.Calculate(worker, 5, 1, 5).Should().Be(1);
        WorkerLevel.Calculate(worker with { MinimumOffersForRate = 20 }, 5, 1, 5).Should().Be(2);
    }

    [Fact]
    public void AWorkerAtTheTopOfAShortLadder_HasNothingNext()
    {
        var ladder = LevelLadder.WorkerDefaults with
        {
            Rungs = [new(1, "New", 0, 0m), new(2, "Seasoned", 3, 0m, MinBusinesses: 1)],
        };

        WorkerLevel.Calculate(ladder, 3, 1).Should().Be(2);
        WorkerLevel.NextLevelRequirement(ladder, 3, 1).Should().BeNull();
        WorkerLevel.JobsToNextLevel(ladder, 3, 1).Should().BeNull();
        WorkerLevel.JobsToNextLevel(ladder, 1, 1).Should().Be(2);
    }

    [Fact]
    public void ANoOffersMinimumOfZero_NeverDividesByZero() =>
        WorkerLevel.Calculate(LevelLadder.WorkerDefaults with { MinimumOffersForRate = 0 }, 0)
            .Should().Be(1);

    // ---- A ladder that cannot be used is refused --------------------------------------------

    public static TheoryData<string, LevelRung[]> BadLadders => new()
    {
        { "empty", [] },
        { "no level 1", [new(2, "Two", 5, 0m)] },
        { "a gap", [new(1, "One", 0, 0m), new(3, "Three", 5, 0m)] },
        { "a repeat", [new(1, "One", 0, 0m), new(2, "Two", 5, 0m), new(2, "Again", 6, 0m)] },
        { "no name", [new(1, "One", 0, 0m), new(2, " ", 5, 0m)] },
        { "rating above 5", [new(1, "One", 0, 0m), new(2, "Two", 5, 5.1m)] },
        { "negative jobs", [new(1, "One", 0, 0m), new(2, "Two", -1, 0m)] },
        { "rate above 1", [new(1, "One", 0, 0m), new(2, "Two", 5, 0m, MinAnsweredRate: 1.5m)] },
        { "a rung asking less than the one below", [new(1, "One", 0, 0m), new(2, "Two", 10, 0m), new(3, "Three", 5, 0m)] },
        { "too many", [.. Enumerable.Range(1, LevelLadder.MostLevels + 1).Select(i => new LevelRung(i, $"L{i}", i, 0m))] },
    };

    [Theory]
    [MemberData(nameof(BadLadders))]
    public void Problem_NamesWhatIsWrong(string because, LevelRung[] rungs) =>
        LevelLadder.Problem(rungs).Should().NotBeNull(because);

    [Fact]
    public void Problem_IsNullForBothShippedLadders()
    {
        LevelLadder.Problem(LevelLadder.BusinessDefaults.Rungs).Should().BeNull();
        LevelLadder.Problem(LevelLadder.WorkerDefaults.Rungs).Should().BeNull();
    }

    [Fact]
    public void Problem_IgnoresLevelOnesThresholds() =>
        LevelLadder.Problem([new(1, "One", 50, 4m), new(2, "Two", 5, 3m)]).Should().BeNull();

    // ---- Reading the table into the rules -----------------------------------------------------

    [Fact]
    public void WithLevelRungs_NoRows_KeepsTheShippedLadder() =>
        PlatformRules.Defaults.WithLevelRungs(LevelAudience.Business, []).Should().Be(PlatformRules.Defaults);

    [Fact]
    public void WithLevelRungs_ABadLadder_KeepsTheShippedOneAndReportsIt()
    {
        var rejected = new List<string>();

        var rules = PlatformRules.Defaults.WithLevelRungs(
            LevelAudience.Worker, [new(1, "One", 0, 0m), new(3, "Three", 5, 0m)], (k, _) => rejected.Add(k));

        rules.WorkerLevels.Should().Be(LevelLadder.WorkerDefaults);
        rejected.Should().ContainSingle().Which.Should().Contain("Worker");
    }

    [Fact]
    public void WithLevelRungs_AGoodLadder_ReplacesOnlyThatAudience_InLevelOrder()
    {
        var rules = PlatformRules.Defaults.WithLevelRungs(
            LevelAudience.Business, [new(2, "Pro", 3, 0m), new(1, "Starter", 0, 0m)]);

        rules.BusinessLevels.Rungs.Select(r => r.Name).Should().Equal("Starter", "Pro");
        rules.BusinessLevels.MinimumReviewsForAverage.Should().Be(LevelLadder.BusinessDefaults.MinimumReviewsForAverage);
        rules.WorkerLevels.Should().Be(LevelLadder.WorkerDefaults);
    }

    [Fact]
    public void TheMinimums_AreReadFromPlatformSettings()
    {
        var rules = PlatformRules.From(new Dictionary<string, string>
        {
            ["business-level.min-reviews-for-average"] = "7",
            ["worker-level.min-reviews-for-average"] = "4",
            ["worker-level.min-offers-for-rate"] = "12",
        });

        rules.BusinessLevels.MinimumReviewsForAverage.Should().Be(7);
        rules.WorkerLevels.MinimumReviewsForAverage.Should().Be(4);
        rules.WorkerLevels.MinimumOffersForRate.Should().Be(12);
        rules.BusinessLevels.Rungs.Should().BeSameAs(LevelLadder.BusinessDefaults.Rungs);
    }

    [Theory]
    [InlineData("business-level.min-reviews-for-average", "0")]
    [InlineData("worker-level.min-offers-for-rate", "101")]
    public void TheMinimums_OutOfRange_KeepTheDefault(string key, string value) =>
        PlatformRules.From(new Dictionary<string, string> { [key] = value }).Should().Be(PlatformRules.Defaults);
}
