using FluentAssertions;
using Zuno.Domain.ValueObjects;

namespace Zuno.Application.UnitTests.Specifications;

/// <summary>
/// A stored level follows the earned level one rung at a time: up after enough time at a level, down
/// only after a grace period below it.
/// </summary>
public class GradualBusinessLevelTests
{
    private static readonly DateTimeOffset Now = new(2026, 11, 5, 10, 0, 0, TimeSpan.Zero);
    private static readonly LevelPace Pace = new(TimeSpan.FromDays(14), TimeSpan.FromDays(7));

    private static LevelPosition At(int level, int? daysAtLevel = null, int? daysBelow = null) => new(
        level,
        daysAtLevel is { } held ? Now.AddDays(-held) : null,
        daysBelow is { } below ? Now.AddDays(-below) : null);

    [Fact]
    public void ThreeRungsEarned_StepsUpOnlyOne() =>
        BusinessLevel.Move(At(1), earned: 4, Now, Pace).Should().Be(new LevelPosition(2, Now, null));

    [Fact]
    public void LevelHeldSinceBeforeTracking_MayStepUpAtOnce() =>
        BusinessLevel.Move(At(3), earned: 5, Now, Pace).Level.Should().Be(4);

    [Fact]
    public void AfterAStep_WaitsFourteenDaysBeforeTheNext()
    {
        var stepped = BusinessLevel.Move(At(1), earned: 5, Now, Pace);

        var tooSoon = BusinessLevel.Move(stepped, earned: 5, Now.AddDays(13), Pace);
        tooSoon.Should().Be(stepped);

        var onTime = BusinessLevel.Move(stepped, earned: 5, Now.AddDays(14), Pace);
        onTime.Should().Be(new LevelPosition(3, Now.AddDays(14), null));
    }

    [Fact]
    public void FallingBelow_StartsTheGrace_WithoutDropping() =>
        BusinessLevel.Move(At(3, daysAtLevel: 30), earned: 2, Now, Pace)
            .Should().Be(new LevelPosition(3, Now.AddDays(-30), Now));

    [Fact]
    public void StillBelow_InsideTheGrace_KeepsTheLevel() =>
        BusinessLevel.Move(At(3, daysAtLevel: 30, daysBelow: 6), earned: 1, Now, Pace).Level.Should().Be(3);

    [Fact]
    public void StillBelow_AfterSevenDays_DropsOnlyOne() =>
        BusinessLevel.Move(At(3, daysAtLevel: 30, daysBelow: 7), earned: 1, Now, Pace)
            .Should().Be(new LevelPosition(2, Now, null));

    [Fact]
    public void RecoveringInsideTheGrace_ForgetsTheSlip() =>
        BusinessLevel.Move(At(3, daysAtLevel: 30, daysBelow: 3), earned: 3, Now, Pace)
            .Should().Be(new LevelPosition(3, Now.AddDays(-30), null));

    [Fact]
    public void EarningMoreDuringTheGrace_ClearsTheSlip_EvenWhenTooSoonToClimb() =>
        BusinessLevel.Move(At(3, daysAtLevel: 2, daysBelow: 1), earned: 5, Now, Pace)
            .Should().Be(new LevelPosition(3, Now.AddDays(-2), null));

    [Fact]
    public void NeverDropsBelowLevelOne() =>
        BusinessLevel.Move(At(1, daysBelow: 30), earned: 0, Now, Pace).Level.Should().Be(1);

    [Fact]
    public void ThePace_FollowsTheSettingsTable()
    {
        var rules = Zuno.Application.Common.Settings.PlatformRules.From(new Dictionary<string, string>
        {
            ["business-level.min-days-at-level"] = "30",
            ["business-level.drop-grace-days"] = "2",
        });

        rules.BusinessLevelPace.Should().Be(new LevelPace(TimeSpan.FromDays(30), TimeSpan.FromDays(2)));
        BusinessLevel.Move(At(2, daysAtLevel: 20), earned: 3, Now, rules.BusinessLevelPace).Level.Should().Be(2);
        BusinessLevel.Move(At(2, daysAtLevel: 20, daysBelow: 2), earned: 1, Now, rules.BusinessLevelPace).Level.Should().Be(1);
    }
}
