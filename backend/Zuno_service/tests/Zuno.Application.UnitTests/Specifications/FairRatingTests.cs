using FluentAssertions;
using Zuno.Application.Common.Settings;
using Zuno.Domain.ValueObjects;

namespace Zuno.Application.UnitTests.Specifications;

/// <summary>
/// The fair average every rating in the app goes through: a few typical ratings to start from, real
/// ratings pulling away from them, and nothing shown below the review minimum.
/// </summary>
public class FairRatingTests
{
    private static readonly PlatformRules Rules = PlatformRules.Defaults;

    private static decimal? FiveStars(int count) => Rules.FairRating(5m * count, count);

    [Fact]
    public void Defaults_MatchTheRentApi()
    {
        Rules.RatingPriorAverage.Should().Be(4.0m);
        Rules.RatingPriorWeight.Should().Be(5);
        Rules.BusinessLevels.MinimumReviewsForAverage.Should().Be(3);
    }

    [Fact]
    public void OneFiveStar_IsBelowTheMinimum_SoNoAverage() => FiveStars(1).Should().BeNull();

    [Fact]
    public void TwoFiveStars_AreStillBelowTheMinimum() => FiveStars(2).Should().BeNull();

    [Fact]
    public void ThreeFiveStars_ReadAs4Point4() => FiveStars(3).Should().Be(4.4m);

    [Fact]
    public void TenFiveStars_ReadAs4Point7() => FiveStars(10).Should().Be(4.7m);

    [Fact]
    public void ManyRatings_ApproachTheRealMean() => Rules.FairRating(3m * 1000, 1000).Should().Be(3.0m);

    [Theory]
    // (sum + 4.0 × 5) / (count + 5), to one place.
    [InlineData(3, 3, 2.9)]     // three 1★: 23 / 8 = 2.875
    [InlineData(12, 3, 4.0)]    // three 4★: 32 / 8 = 4.0
    [InlineData(20, 5, 4.0)]    // five 4★ stay exactly at the prior
    [InlineData(45, 10, 4.3)]   // 65 / 15 = 4.333
    public void Formula_AddsThePriorThenDivides(decimal sum, int count, decimal expected) =>
        Rules.FairRating(sum, count).Should().Be(expected);

    [Fact]
    public void NoRatings_IsNull_EvenWithNoMinimum() =>
        FairRating.Of(0m, 0, 4.0m, 5, minCount: 0).Should().BeNull();

    [Fact]
    public void Of_IsTheSameFormulaAsTheRules() =>
        FairRating.Of(15m, 3, 4.0m, 5, 3).Should().Be(FiveStars(3));

    [Fact]
    public void ThePrior_FollowsTheSettingsTable()
    {
        // A weight of 0 is a plain mean; a higher minimum hides more averages.
        var plain = PlatformRules.From(new Dictionary<string, string> { ["rating.prior-weight"] = "0" });
        plain.FairRating(15m, 3).Should().Be(5.0m);

        var stricter = PlatformRules.From(new Dictionary<string, string>
        {
            ["rating.prior-average"] = "3.0",
            ["business-level.min-reviews-for-average"] = "5",
        });
        stricter.FairRating(15m, 3).Should().BeNull();
        stricter.FairRating(25m, 5).Should().Be(4.0m);
    }

    [Theory]
    [InlineData("rating.prior-average", "0.5")]
    [InlineData("rating.prior-average", "5.5")]
    [InlineData("rating.prior-average", "abc")]
    [InlineData("rating.prior-weight", "-1")]
    public void OutOfRangeSettings_KeepTheDefaults(string key, string value)
    {
        var rejected = new List<string>();
        var rules = PlatformRules.From(new Dictionary<string, string> { [key] = value }, (k, _) => rejected.Add(k));

        rules.RatingPrior.Should().Be(PlatformRules.Defaults.RatingPrior);
        rejected.Should().Equal(key);
    }
}
