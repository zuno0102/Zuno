using System.Globalization;
using Microsoft.EntityFrameworkCore;
using Zuno.Rent.Domain.Entities;
using Zuno.Rent.Domain.Exceptions;

namespace Zuno.Rent.Application.Common;

/// <summary>How many of an item can still be promised for some dates, and what holds the rest.</summary>
public class RentalAvailabilityDto
{
    /// <summary>What the business owns.</summary>
    public int Total { get; set; }

    /// <summary>On orders that hold stock and overlap the dates.</summary>
    public int Held { get; set; }

    /// <summary>What a new order for those dates can take — 0 while the item is switched off.</summary>
    public int Available { get; set; }
}

/// <summary>
/// The one availability rule: what the business owns, minus the pieces on this item's orders that
/// hold stock (status table: booked or out) and overlap the dates asked for. Orders on other dates do
/// not count — 2000 chairs can serve four weekends' weddings — and returned or cancelled orders hold
/// nothing.
/// </summary>
internal static class RentalAvailability
{
    /// <summary>
    /// Orders whose pieces are spoken for: booked or out, per the status table — and, for an order
    /// still waiting for its advance, only until its hold runs out. Read this way, a lapsed hold frees
    /// the pieces at once, whenever the lapse job gets to cancelling it.
    /// </summary>
    public static IQueryable<RentalOrder> HoldingOrders(this IRentDbContext dbContext) =>
        dbContext.RentalOrders.Where(o =>
            dbContext.RentalOrderStatuses.Any(s => s.Code == o.Status && (s.CountsAsBooked || s.CountsAsOut))
            && (o.HoldUntil == null || o.HoldUntil > DateTimeOffset.UtcNow));

    public static async Task<RentalAvailabilityDto> AvailabilityAsync(
        this IRentDbContext dbContext,
        RentalItem item,
        DateTimeOffset start,
        DateTimeOffset end,
        Guid? excludeOrderId,
        CancellationToken cancellationToken)
    {
        // Stored in UTC; the app sends the business's own offset.
        start = start.ToUniversalTime();
        end = end.ToUniversalTime();

        // Two stretches overlap when each starts before the other ends.
        var held = await dbContext.HoldingOrders()
            .Where(o => o.RentalItemId == item.Id
                && o.StartDate < end
                && o.EndDate > start
                && (excludeOrderId == null || o.Id != excludeOrderId))
            .SumAsync(o => (int?)o.Quantity, cancellationToken) ?? 0;

        return new RentalAvailabilityDto
        {
            Total = item.QuantityOwned,
            Held = held,
            Available = item.IsAvailable ? Math.Max(0, item.QuantityOwned - held) : 0,
        };
    }

    /// <summary>Refuses [quantity] beyond what the dates leave, naming the number that is left.</summary>
    public static async Task EnsureAvailableAsync(
        this IRentDbContext dbContext,
        RentalItem item,
        int quantity,
        DateTimeOffset start,
        DateTimeOffset end,
        CancellationToken cancellationToken)
    {
        if (!item.IsAvailable)
        {
            throw new DomainException($"{item.Name} is switched off, so it cannot be booked now.");
        }

        var availability = await dbContext.AvailabilityAsync(item, start, end, null, cancellationToken);
        if (availability.Available < quantity)
        {
            throw new DomainException(
                $"Only {availability.Available} {item.Name} available for {Dates(start, end)}; this order needs {quantity}.");
        }
    }

    /// <summary>"1 Nov" or "1 Nov – 3 Nov", in the dates' own offset — the business's day, as it sent them.</summary>
    public static string Dates(DateTimeOffset start, DateTimeOffset end)
    {
        var from = start.ToString("d MMM", CultureInfo.InvariantCulture);
        var to = end.ToString("d MMM", CultureInfo.InvariantCulture);
        return from == to ? from : $"{from} – {to}";
    }
}
