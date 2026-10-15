using FluentAssertions;
using Zuno.Application.Modules.Customer.Queries.GetDailyBanners;

namespace Zuno.Application.UnitTests.Modules.Customer;

/// <summary>
/// The rule that decides which seven services are on the customer's banner today.
/// </summary>
/// <remarks>
/// The whole point of the banner is that it moves: seven services today, a different seven tomorrow,
/// and round again once everybody has had a turn. Picking at random would show some businesses twice
/// in a week and others never, so the window is arithmetic and these tests pin the properties that
/// makes it worth having.
/// </remarks>
public class DailyBannerWindowTests
{
    private const int Count = GetDailyBannersQueryHandler.BannerCount;

    private static List<Guid> Ids(int howMany) =>
        [.. Enumerable.Range(1, howMany).Select(i => new Guid($"00000000-0000-0000-0000-{i:D12}"))];

    private static DateTimeOffset Day(int offset) =>
        new DateTimeOffset(2026, 10, 5, 9, 0, 0, TimeSpan.Zero).AddDays(offset);

    [Fact]
    public void Returns_seven_when_there_are_plenty()
    {
        var window = GetDailyBannersQueryHandler.Window(Ids(50), Day(0), Count);

        window.Should().HaveCount(Count);
        window.Should().OnlyHaveUniqueItems();
    }

    [Fact]
    public void Tomorrow_shows_a_completely_different_seven()
    {
        // The thing that was asked for: today's seven, and tomorrow without any of them.
        var ids = Ids(50);

        var today = GetDailyBannersQueryHandler.Window(ids, Day(0), Count);
        var tomorrow = GetDailyBannersQueryHandler.Window(ids, Day(1), Count);

        tomorrow.Should().NotIntersectWith(today);
    }

    [Fact]
    public void A_week_of_days_never_repeats_a_service()
    {
        // 50 services is seven full days before the window has to wrap.
        var ids = Ids(50);

        var shown = Enumerable.Range(0, 7)
            .SelectMany(d => GetDailyBannersQueryHandler.Window(ids, Day(d), Count))
            .ToList();

        shown.Should().HaveCount(49);
        shown.Should().OnlyHaveUniqueItems();
    }

    [Fact]
    public void Everybody_gets_a_turn_before_anybody_gets_a_second()
    {
        // The reason for rotating at all: a business below the fold is never permanently invisible.
        var ids = Ids(49);

        var shown = Enumerable.Range(0, 7)
            .SelectMany(d => GetDailyBannersQueryHandler.Window(ids, Day(d), Count))
            .ToList();

        shown.Should().BeEquivalentTo(ids);
    }

    [Fact]
    public void The_same_day_always_gives_the_same_seven()
    {
        // Two phones opening the app an hour apart must agree, and so must one phone before and
        // after a refresh.
        var ids = Ids(30);

        var morning = GetDailyBannersQueryHandler.Window(ids, Day(0), Count);
        var evening = GetDailyBannersQueryHandler.Window(
            ids,
            Day(0).AddHours(10),
            Count);

        evening.Should().Equal(morning);
    }

    [Fact]
    public void Wraps_round_the_end_rather_than_running_short()
    {
        // 10 services: the window starting at 7 has to come back round to the front for the rest,
        // or the banner would show three items on some days and seven on others.
        var ids = Ids(10);

        var window = GetDailyBannersQueryHandler.Window(ids, Day(1), Count);

        window.Should().HaveCount(Count);
        window.Should().OnlyHaveUniqueItems();
    }

    [Fact]
    public void A_catalogue_smaller_than_one_page_shows_everybody_every_day()
    {
        // Rotating four services through a seven-slot banner would hide somebody for no reason.
        var ids = Ids(4);

        GetDailyBannersQueryHandler.Window(ids, Day(0), Count).Should().Equal(ids);
        GetDailyBannersQueryHandler.Window(ids, Day(1), Count).Should().Equal(ids);
    }

    [Fact]
    public void An_empty_catalogue_gives_an_empty_banner()
    {
        GetDailyBannersQueryHandler.Window([], Day(0), Count).Should().BeEmpty();
    }
}
