using Zuno.Rent.Domain.Enums;
using Zuno.Rent.Domain.Exceptions;

namespace Zuno.Rent.Domain.Entities;

/// <summary>
/// One step of an item's cancellation charge: cancelling <see cref="UnitsBefore"/> or more days (or
/// hours, for an hourly item) before the start costs <see cref="Percent"/> of the order. "5+ days →
/// 0.5%", "2+ days → 1%", "same day (0) → 2%".
/// </summary>
/// <remarks>Stored as part of the item, and copied onto each order when booked so a later change never touches it.</remarks>
public class RentalCancelStep
{
    /// <summary>Whole days (hours for an hourly item) before the start from which this step applies.</summary>
    public int UnitsBefore { get; set; }

    /// <summary>Percent of the order kept when the customer cancels at this point.</summary>
    public decimal Percent { get; set; }
}

/// <summary>
/// The cancellation charge, worked out one way for the booking screen, the cancel button and the
/// record: the step for how long before the start the customer cancels, as a percent of the order,
/// never more than they have paid. The business cancelling owes the customer everything back.
/// </summary>
public static class RentalCancellation
{
    /// <summary>
    /// Whole days before the start, or whole hours for an hourly item; 0 once the start has come.
    /// Counted in 24-hour days from now, so "1 day before" means at least a full day ahead.
    /// </summary>
    public static int UnitsBefore(RentalPriceType priceType, DateTimeOffset start, DateTimeOffset now)
    {
        var left = start - now;
        if (left <= TimeSpan.Zero)
        {
            return 0;
        }

        return (int)Math.Floor(priceType == RentalPriceType.Hourly ? left.TotalHours : left.TotalDays);
    }

    /// <summary><c>Hour</c> for an hourly item, otherwise <c>Day</c> — what the app counts steps in.</summary>
    public static string UnitOf(RentalPriceType priceType) => priceType == RentalPriceType.Hourly ? "Hour" : "Day";

    /// <summary>
    /// The percent for a per-rental-day charge: [percentPerDay] for each day (or hour) the order is
    /// for, never above [cap] — the limit for the kind of item when it was booked.
    /// </summary>
    public static decimal PerRentalDay(decimal percentPerDay, int units, decimal cap) =>
        Math.Min(percentPerDay * Math.Max(1, units), cap);

    /// <summary>The step that applies: the one with the most units before that is not more than <paramref name="unitsBefore"/>; 0% with no steps.</summary>
    public static decimal PercentFor(IEnumerable<RentalCancelStep> steps, int unitsBefore) =>
        steps
            .Where(s => s.UnitsBefore <= unitsBefore)
            .OrderByDescending(s => s.UnitsBefore)
            .Select(s => s.Percent)
            .FirstOrDefault();

    /// <summary>The charge: percent of the order, rounded to paise, never more than what was paid.</summary>
    public static decimal Charge(decimal orderAmount, decimal percent, decimal netPaid) =>
        Math.Max(0, Math.Min(decimal.Round(orderAmount * percent / 100m, 2, MidpointRounding.AwayFromZero), netPaid));

    /// <summary>
    /// Checks a business's steps against the category's limit before they are kept: at most the
    /// limit, one step per point in time, a same-day step whenever there are any, and never cheaper
    /// as the start comes closer.
    /// </summary>
    public static List<RentalCancelStep> Validated(IEnumerable<RentalCancelStep> steps, decimal limitPercent)
    {
        var ordered = steps.OrderBy(s => s.UnitsBefore).ToList();
        if (ordered.Count == 0)
        {
            return ordered;
        }

        if (ordered.Any(s => s.UnitsBefore < 0))
        {
            throw new DomainException("A cancellation step starts at 0 (same day) or later.");
        }

        if (ordered.Select(s => s.UnitsBefore).Distinct().Count() != ordered.Count)
        {
            throw new DomainException("Each cancellation step needs its own number of days or hours.");
        }

        if (ordered[0].UnitsBefore != 0)
        {
            throw new DomainException("Add a step for cancelling on the start day itself (0).");
        }

        if (ordered.Any(s => s.Percent < 0 || s.Percent > limitPercent))
        {
            throw new DomainException($"This kind of item allows a cancellation charge of at most {limitPercent:0.##}%.");
        }

        for (var i = 1; i < ordered.Count; i++)
        {
            if (ordered[i].Percent > ordered[i - 1].Percent)
            {
                throw new DomainException("Cancelling earlier cannot cost more than cancelling later.");
            }
        }

        return ordered.Select(s => new RentalCancelStep { UnitsBefore = s.UnitsBefore, Percent = s.Percent }).ToList();
    }
}

/// <summary>The ways a cancellation charge can be worked out, as the item form offers them. Table-driven.</summary>
public class RentalCancelChargeTypeOption
{
    public RentalCancelChargeType Code { get; set; }

    /// <summary>"Per rental day".</summary>
    public string Name { get; set; } = string.Empty;

    /// <summary>The line under it, e.g. "1% a day: a 2-day order costs 2%".</summary>
    public string Detail { get; set; } = string.Empty;

    public short DisplayOrder { get; set; }

    public bool IsActive { get; set; } = true;
}

/// <summary>
/// How a refund method is named and what each side is told about it. Table-driven, so the wording —
/// "1 to 5 working days" — changes without a release.
/// </summary>
public class RentalRefundModeOption
{
    public RentalRefundMode Code { get; set; }

    /// <summary>"Online", "In hand".</summary>
    public string Name { get; set; } = string.Empty;

    /// <summary>What the customer reads, e.g. "Back to the card or UPI you paid with in 1 to 5 working days."</summary>
    public string CustomerText { get; set; } = string.Empty;

    /// <summary>What the business reads when choosing it.</summary>
    public string BusinessText { get; set; } = string.Empty;

    public bool IsActive { get; set; } = true;

    public short DisplayOrder { get; set; }
}
