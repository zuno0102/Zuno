using FluentAssertions;
using FluentValidation;
using Zuno.Application.Common.Settings;
using Zuno.Application.Modules.Booking.Commands.UpdateCrewSize;
using Zuno.Application.Modules.Booking.Common;
using Zuno.Application.Modules.Business.Commands.SetBusinessServiceQuestions;
using Zuno.Application.Modules.HiringPost.Commands.CreateHiringPost;
using Zuno.Application.Modules.HiringPost.Common;

namespace Zuno.Application.UnitTests.Common;

/// <summary>
/// Business rules come from the platform_settings table. A good row changes the rule; a bad one can
/// never take it outside what the code supports.
/// </summary>
public class PlatformRulesTests
{
    private static PlatformRules From(params (string Key, string Value)[] rows) =>
        PlatformRules.From(rows.ToDictionary(r => r.Key, r => r.Value));

    // ---- Reading the table --------------------------------------------------------------------

    [Fact]
    public void From_AnEmptyTable_GivesTheShippedDefaults() =>
        From().Should().Be(PlatformRules.Defaults);

    [Fact]
    public void From_AValidRow_ChangesThatRuleOnly()
    {
        var rules = From(("schedule.travel-buffer-minutes", "45"));

        rules.TravelBufferMinutes.Should().Be(45);
        rules.Should().Be(PlatformRules.Defaults with { TravelBufferMinutes = 45 });
    }

    [Theory]
    [InlineData("service-area.max-distance-km", "0")]        // below its range
    [InlineData("service-area.max-distance-km", "5000")]     // above its range
    [InlineData("service-area.max-distance-km", "NaN")]
    [InlineData("hiring-post.max-workers", "twenty")]        // does not parse
    [InlineData("hiring-post.max-workers", "2.5")]           // not a whole number
    [InlineData("hiring-post.max-workers", "")]
    public void From_AnUnusableRow_KeepsTheDefaultAndReportsIt(string key, string value)
    {
        var rejected = new List<string>();

        var rules = PlatformRules.From(new Dictionary<string, string> { [key] = value }, (k, _) => rejected.Add(k));

        rules.Should().Be(PlatformRules.Defaults);
        rejected.Should().Contain(key);
    }

    [Fact]
    public void From_ValuesExactlyAtTheEdgesOfTheirRange_AreAccepted()
    {
        var rules = From(("hiring-post.max-workers", "1"), ("order.max-crew-size", "10000"));

        rules.HiringPostMaxWorkers.Should().Be(1);
        rules.OrderMaxCrewSize.Should().Be(10000);
    }

    [Fact]
    public void From_AMinimumAboveItsMaximum_ResetsThePair()
    {
        var rules = From(("hiring-post.min-duration-minutes", "600"), ("hiring-post.max-duration-minutes", "300"));

        rules.HiringPostMinDurationMinutes.Should().Be(PlatformRules.Defaults.HiringPostMinDurationMinutes);
        rules.HiringPostMaxDurationMinutes.Should().Be(PlatformRules.Defaults.HiringPostMaxDurationMinutes);
    }

    [Fact]
    public void From_ADefaultPageAboveTheMaximum_ResetsThePair()
    {
        var rules = From(("hiring-feed.default-page-size", "300"), ("hiring-feed.max-page-size", "100"));

        rules.HiringFeedDefaultPageSize.Should().Be(PlatformRules.Defaults.HiringFeedDefaultPageSize);
        rules.HiringFeedMaxPageSize.Should().Be(PlatformRules.Defaults.HiringFeedMaxPageSize);
    }

    [Fact]
    public void From_UnknownKeys_AreIgnored() =>
        From(("someone.typed-this", "1")).Should().Be(PlatformRules.Defaults);

    [Fact]
    public void From_KeysInAnyCase_StillMatch()
    {
        var values = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase)
        {
            ["SCHEDULE.TRAVEL-BUFFER-MINUTES"] = "40",
        };

        PlatformRules.From(values).TravelBufferMinutes.Should().Be(40);
    }

    [Fact]
    public void Definitions_HaveUniqueKeys_AndEveryDefaultIsInsideItsOwnRange()
    {
        PlatformRules.Definitions.Select(d => d.Key).Should().OnlyHaveUniqueItems();

        foreach (var d in PlatformRules.Definitions)
        {
            var stored = d.Format(PlatformRules.Defaults);
            d.TryApply(PlatformRules.Defaults, stored, out var roundTripped).Should().BeTrue(d.Key);
            roundTripped.Should().Be(PlatformRules.Defaults, d.Key);
        }
    }

    [Theory]
    [InlineData(0, 1)]
    [InlineData(-5, 1)]
    [InlineData(40, 40)]
    [InlineData(100, 100)]
    [InlineData(100_000, 100)]   // one request may not pull the whole catalogue
    public void ServiceSearchPageSize_IsHeldInsideTheConfiguredBounds(int requested, int expected) =>
        PlatformRules.Defaults.ServiceSearchPageSize(requested).Should().Be(expected);

    [Theory]
    [InlineData(null, 60)]
    [InlineData(0, 60)]
    [InlineData(25, 25)]
    [InlineData(100, 100)]
    [InlineData(100_000, 100)]   // a client asking for the whole country gets the maximum
    public void HiringFeedPageSize_IsHeldInsideTheConfiguredBounds(int? requested, int expected) =>
        PlatformRules.Defaults.HiringFeedPageSize(requested).Should().Be(expected);

    // ---- The rules follow the table, not a literal -----------------------------------------

    [Theory]
    [InlineData(10, 10, true)]
    [InlineData(10, 11, false)]
    [InlineData(500, 400, true)]
    public void CrewSize_FollowsTheConfiguredMaximum(int maximum, int asked, bool allowed)
    {
        var settings = new TestPlatformSettings(PlatformRules.Defaults with { OrderMaxCrewSize = maximum });

        var result = new UpdateCrewSizeCommandValidator(settings)
            .Validate(new UpdateCrewSizeCommand { BookingId = Guid.NewGuid(), RequiredWorkerCount = asked });

        result.IsValid.Should().Be(allowed);
    }

    [Fact]
    public void CrewSize_OfZero_IsAlwaysRefused() =>
        new UpdateCrewSizeCommandValidator(new TestPlatformSettings())
            .Validate(new UpdateCrewSizeCommand { BookingId = Guid.NewGuid(), RequiredWorkerCount = 0 })
            .IsValid.Should().BeFalse();

    [Fact]
    public void ServiceQuestions_FollowTheConfiguredMaximum()
    {
        var settings = new TestPlatformSettings(PlatformRules.Defaults with { ServiceMaxQuestions = 2 });
        var validator = new SetBusinessServiceQuestionsCommandValidator(settings);

        SetBusinessServiceQuestionsCommand With(int count) => new()
        {
            ServiceId = Guid.NewGuid(),
            Questions = [.. Enumerable.Range(0, count).Select(i => new ServiceQuestionInput { Prompt = $"Q{i}" })],
        };

        validator.Validate(With(2)).IsValid.Should().BeTrue();
        validator.Validate(With(3)).Errors.Should().Contain(e => e.ErrorMessage.Contains("at most 2"));
    }

    [Theory]
    [InlineData(30, 600, 30, true)]
    [InlineData(30, 600, 29, false)]
    [InlineData(30, 600, 600, true)]
    [InlineData(30, 600, 601, false)]
    public void HiringPostDuration_FollowsTheConfiguredRange(int min, int max, int asked, bool allowed)
    {
        var settings = new TestPlatformSettings(PlatformRules.Defaults with
        {
            HiringPostMinDurationMinutes = min,
            HiringPostMaxDurationMinutes = max,
        });
        var validator = new InlineValidator<CreateHiringPostCommand>();
        validator.RuleFor(x => x.DurationMinutes).ValidDuration(settings);

        validator.Validate(new CreateHiringPostCommand { DurationMinutes = asked }).IsValid.Should().Be(allowed);
    }

    [Fact]
    public void HiringPostDuration_Omitted_IsAllowed_AndUsesTheDefaultLater()
    {
        var validator = new InlineValidator<CreateHiringPostCommand>();
        validator.RuleFor(x => x.DurationMinutes).ValidDuration(new TestPlatformSettings());

        validator.Validate(new CreateHiringPostCommand { DurationMinutes = null }).IsValid.Should().BeTrue();
    }

    [Fact]
    public void WorkersNeeded_FollowsTheConfiguredMaximum()
    {
        var settings = new TestPlatformSettings(PlatformRules.Defaults with { HiringPostMaxWorkers = 5 });
        var validator = new InlineValidator<CreateHiringPostCommand>();
        validator.RuleFor(x => x.WorkersNeeded).ValidWorkersNeeded(settings);

        validator.Validate(new CreateHiringPostCommand { WorkersNeeded = 5 }).IsValid.Should().BeTrue();
        validator.Validate(new CreateHiringPostCommand { WorkersNeeded = 6 }).IsValid.Should().BeFalse();
        validator.Validate(new CreateHiringPostCommand { WorkersNeeded = 0 }).IsValid.Should().BeFalse();
    }

    [Fact]
    public void ServiceArea_FollowsTheConfiguredRadius()
    {
        // A pin about 110 km from the only served centre.
        var served = new List<(double, double)> { (8.18, 77.41) };
        const double pinLat = 9.18, pinLon = 77.41;

        ServiceAreaCheck.IsServed(pinLat, pinLon, served, served, PlatformRules.Defaults with { ServiceAreaMaxDistanceKm = 150 })
            .Should().BeTrue();
        ServiceAreaCheck.IsServed(pinLat, pinLon, served, served, PlatformRules.Defaults with { ServiceAreaMaxDistanceKm = 100 })
            .Should().BeFalse();
    }
}
