using FluentAssertions;
using Zuno.Application.Modules.Notifications.Common;
using Zuno.Domain.Enums;

namespace Zuno.Application.UnitTests.Modules.Notifications;

/// <summary>
/// The wording helpers every notification is built from.
/// </summary>
/// <remarks>
/// Worth testing closely for one reason: <b>a notification's words are written once and never
/// recomputed</b>. A wage shown as <c>1100.00</c> or a Saturday job announced as Sunday cannot be
/// corrected later, because the row has already been read. These are the only place that formatting
/// is decided.
/// </remarks>
public class NotificationTextTests
{
    // Mid-afternoon IST on Wednesday 12 November 2025, expressed in UTC the way the server holds it.
    private static readonly DateTimeOffset Now =
        new(2025, 11, 12, 9, 30, 0, TimeSpan.Zero);

    // ---- money -------------------------------------------------------------------------------

    [Theory]
    [InlineData(900, "₹900")]
    [InlineData(1100, "₹1,100")]
    [InlineData(12000, "₹12,000")]
    [InlineData(150000, "₹1,50,000")]
    public void Whole_rupees_lose_their_decimals(decimal amount, string expected) =>
        NotificationText.Money(amount).Should().Be(expected);

    [Fact]
    public void Paise_are_kept_when_there_are_any()
    {
        NotificationText.Money(12500.50m).Should().Be("₹12,500.50");
        NotificationText.Money(99.05m).Should().Be("₹99.05");
    }

    [Theory]
    [InlineData(SalaryUnit.PerEvent, "₹900 per event")]
    [InlineData(SalaryUnit.PerDay, "₹900 a day")]
    [InlineData(SalaryUnit.PerHour, "₹900 an hour")]
    public void A_wage_always_carries_its_unit(SalaryUnit unit, string expected) =>
        NotificationText.Wage(900m, unit).Should().Be(expected);

    // ---- days --------------------------------------------------------------------------------

    [Fact]
    public void Today_and_tomorrow_are_named_rather_than_dated()
    {
        NotificationText.Day(Now.AddHours(3), Now).Should().Be("today");
        NotificationText.Day(Now.AddDays(1), Now).Should().Be("tomorrow");
    }

    [Fact]
    public void A_day_inside_the_week_is_its_weekday()
    {
        // Wednesday + 3 days = Saturday.
        NotificationText.Day(Now.AddDays(3), Now).Should().Be("Saturday");
    }

    [Fact]
    public void Beyond_a_week_a_weekday_would_be_ambiguous_so_it_becomes_a_date()
    {
        NotificationText.Day(Now.AddDays(14), Now).Should().Be("26 Nov");
    }

    /// <remarks>
    /// The case the explicit India offset exists for. 21:00 IST on Saturday is 15:30 UTC that same
    /// Saturday, but a 23:30 IST job is 18:00 UTC — and a job late on Saturday night must never be
    /// announced as Sunday because the API container's clock is UTC.
    /// </remarks>
    [Fact]
    public void A_late_evening_job_keeps_its_own_day_in_India_time()
    {
        // 23:30 IST on Saturday 15 November = 18:00 UTC the same day.
        var lateSaturday = new DateTimeOffset(2025, 11, 15, 18, 0, 0, TimeSpan.Zero);

        NotificationText.Day(lateSaturday, Now).Should().Be("Saturday");
    }

    [Fact]
    public void A_day_that_crosses_midnight_in_utc_is_still_the_right_indian_day()
    {
        // 01:00 IST on Sunday 16 November = 19:30 UTC on Saturday 15 November.
        var earlySunday = new DateTimeOffset(2025, 11, 15, 19, 30, 0, TimeSpan.Zero);

        NotificationText.Day(earlySunday, Now).Should().Be("Sunday");
    }

    [Fact]
    public void A_day_in_a_sentence_takes_a_preposition_only_when_it_needs_one()
    {
        NotificationText.When(Now.AddHours(3), Now).Should().Be("today");
        NotificationText.When(Now.AddDays(1), Now).Should().Be("tomorrow");
        NotificationText.When(Now.AddDays(3), Now).Should().Be("on Saturday");
        NotificationText.When(Now.AddDays(14), Now).Should().Be("on 26 Nov");
    }

    // ---- people ------------------------------------------------------------------------------

    [Fact]
    public void A_person_with_both_names_reads_as_both()
    {
        NotificationText.Person("Ravi", "Kumar").Should().Be("Ravi Kumar");
    }

    /// <remarks>
    /// Without the join, a missing last name leaves "Ravi  accepted the job" — two spaces in the
    /// one sentence somebody reads.
    /// </remarks>
    [Theory]
    [InlineData("Ravi", null)]
    [InlineData("Ravi", "")]
    [InlineData("Ravi", "   ")]
    public void A_missing_last_name_leaves_no_trailing_space(string? first, string? last)
    {
        NotificationText.Person(first, last).Should().Be("Ravi");
    }

    [Fact]
    public void An_account_with_no_name_at_all_still_has_a_subject()
    {
        NotificationText.Person(null, null).Should().Be("Someone");
        NotificationText.Person("  ", "").Should().Be("Someone");
    }

    // ---- quoted messages ---------------------------------------------------------------------

    [Fact]
    public void A_short_message_is_quoted_whole()
    {
        NotificationText.Preview("  can you come at 5?  ").Should().Be("can you come at 5?");
    }

    [Fact]
    public void A_long_message_is_cut_at_a_word_boundary()
    {
        var body = string.Join(' ', Enumerable.Repeat("wedding", 40));

        var preview = NotificationText.Preview(body, maxLength: 40);

        preview.Should().EndWith("…");
        preview.Should().NotContain("weddin…");
        preview.TrimEnd('…').Should().NotEndWith(" ");
    }

    /// <remarks>
    /// A single unbroken token — a pasted URL, a long Malayalam compound — has no space to cut at.
    /// It is still clipped rather than stored whole.
    /// </remarks>
    [Fact]
    public void A_message_with_no_spaces_is_still_clipped()
    {
        var body = new string('x', 200);

        NotificationText.Preview(body, maxLength: 40).Should().HaveLength(41);
    }
}
