using System.Globalization;
using Zuno.Domain.Enums;

namespace Zuno.Application.Modules.Notifications.Common;

/// <summary>
/// The small amount of formatting that notification wording needs.
/// </summary>
/// <remarks>
/// <para>
/// Shared because the words are written once and kept for ever (see
/// <see cref="Zuno.Domain.Entities.Notification"/>). A wage shown as <c>1100.00</c> in one
/// notification and <c>₹1,100</c> in the next cannot be tidied up later — the rows are already sent.
/// </para>
/// <para>
/// <b>Dates are converted to India time explicitly</b>, not with <c>ToLocalTime()</c> as the
/// validation messages elsewhere do. Those are read the instant they are produced, on a machine in
/// the same room as the person reading them. A notification saying "your job on Saturday" is read
/// days later and can never be corrected, and the API runs in a container whose clock is UTC — where
/// a 9pm Saturday job would be announced as Sunday.
/// </para>
/// </remarks>
public static class NotificationText
{
    // Everything in this app is priced in rupees, addressed to Indian districts and worked in IST.
    // A fixed offset rather than a named zone because India has no daylight saving and the lookup
    // name differs between Windows and Linux.
    private static readonly TimeSpan IndiaOffset = TimeSpan.FromMinutes(330);

    private static readonly CultureInfo Culture = CultureInfo.GetCultureInfo("en-IN");

    /// <summary>
    /// A person's name for a notification: <c>Ravi Kumar</c>, or <c>Ravi</c> where that is all we
    /// hold.
    /// </summary>
    /// <remarks>
    /// Trimmed and joined here rather than interpolated at each call site, because a missing last
    /// name otherwise shows up as a trailing space before a verb — "Ravi  accepted the job".
    /// </remarks>
    public static string Person(string? firstName, string? lastName)
    {
        var name = string.Join(' ', new[] { firstName, lastName }
            .Where(part => !string.IsNullOrWhiteSpace(part))
            .Select(part => part!.Trim()));

        // Rather than an empty subject in the one sentence somebody reads. An account with no name
        // at all is a seeded or half-registered one, not a person we can name.
        return string.IsNullOrEmpty(name) ? "Someone" : name;
    }

    /// <summary>An amount as somebody would say it: <c>₹1,100</c>, <c>₹12,500.50</c>.</summary>
    /// <remarks>
    /// Whole rupees lose the decimals. Nobody writes a wage as ₹900.00, and the two extra
    /// characters are two fewer of the business's name on a lock screen.
    /// </remarks>
    public static string Money(decimal amount) =>
        amount == decimal.Truncate(amount)
            ? "₹" + amount.ToString("#,##0", Culture)
            : "₹" + amount.ToString("#,##0.00", Culture);

    /// <summary>
    /// A wage with its unit attached: <c>₹900 per event</c>, <c>₹120 an hour</c>, <c>₹900 a day</c>.
    /// </summary>
    /// <remarks>
    /// The unit is not decoration. ₹800 for a whole event and ₹800 an hour differ by a factor of
    /// eight on a long day, and a worker deciding from a lock screen has only this line to go on.
    /// </remarks>
    public static string Wage(decimal amount, SalaryUnit unit) =>
        Money(amount) + unit switch
        {
            SalaryUnit.PerHour => " an hour",
            SalaryUnit.PerDay => " a day",
            _ => " per event",
        };

    /// <summary>
    /// When something happens, as a person would refer to it: <c>today</c>, <c>tomorrow</c>,
    /// <c>Saturday</c>, or <c>14 Nov</c> once it is far enough out that a weekday is ambiguous.
    /// </summary>
    public static string Day(DateTimeOffset when, DateTimeOffset now)
    {
        var day = when.ToOffset(IndiaOffset).Date;
        var today = now.ToOffset(IndiaOffset).Date;
        var daysAway = (day - today).Days;

        return daysAway switch
        {
            0 => "today",
            1 => "tomorrow",
            // A weekday name only while it can mean just one day. "Saturday" a fortnight out is a
            // question, not a date.
            > 1 and < 7 => day.ToString("dddd", Culture),
            _ => day.ToString("d MMM", Culture),
        };
    }

    /// <summary>
    /// The same day, ready to drop into a sentence: <c>today</c>, <c>tomorrow</c>,
    /// <c>on Saturday</c>, <c>on 14 Nov</c>.
    /// </summary>
    /// <remarks>
    /// "today" and "tomorrow" take no preposition and a date does, which is the kind of detail that
    /// otherwise produces "You're on a job on today" in the one message somebody actually reads.
    /// </remarks>
    public static string When(DateTimeOffset when, DateTimeOffset now)
    {
        var day = Day(when, now);

        return day is "today" or "tomorrow" ? day : "on " + day;
    }

    /// <summary>A time of day: <c>18:30</c>.</summary>
    public static string TimeOfDay(DateTimeOffset when) =>
        when.ToOffset(IndiaOffset).ToString("HH:mm", Culture);

    /// <summary>
    /// A message quoted into a notification's body, clipped so the end is not cut mid-word.
    /// </summary>
    /// <remarks>
    /// Used for chat. The phone truncates anyway; this keeps the preview a readable fragment rather
    /// than a hard cut, and keeps a pasted wall of text out of the table.
    /// </remarks>
    public static string Preview(string body, int maxLength = 140)
    {
        var text = body.Trim();

        if (text.Length <= maxLength)
        {
            return text;
        }

        var cut = text[..maxLength];
        var lastSpace = cut.LastIndexOf(' ');

        return (lastSpace > maxLength / 2 ? cut[..lastSpace] : cut).TrimEnd() + "…";
    }
}
