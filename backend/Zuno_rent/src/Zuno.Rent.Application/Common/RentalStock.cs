using Microsoft.EntityFrameworkCore;
using Zuno.Rent.Domain.Entities;

namespace Zuno.Rent.Application.Common;

/// <summary>
/// Out stock: pieces on orders whose status the status table marks as out with the customer. One
/// definition, used by the Stock page and by every save that changes the quantity owned.
/// </summary>
internal static class RentalStock
{
    /// <summary>Orders whose pieces are with a customer now.</summary>
    public static IQueryable<RentalOrder> OutOrders(this IRentDbContext dbContext) =>
        dbContext.RentalOrders.Where(o =>
            dbContext.RentalOrderStatuses.Any(s => s.Code == o.Status && s.CountsAsOut));

    /// <summary>Orders whose pieces are promised to a customer but not yet sent.</summary>
    /// <remarks>An order awaiting its advance counts only while its hold lasts, as for availability.</remarks>
    public static IQueryable<RentalOrder> BookedOrders(this IRentDbContext dbContext) =>
        dbContext.RentalOrders.Where(o =>
            dbContext.RentalOrderStatuses.Any(s => s.Code == o.Status && s.CountsAsBooked)
            && (o.HoldUntil == null || o.HoldUntil > DateTimeOffset.UtcNow));

    /// <summary>Pieces of one item out with customers now.</summary>
    public static async Task<int> QuantityOutAsync(
        this IRentDbContext dbContext, Guid rentalItemId, CancellationToken cancellationToken) =>
        await dbContext.OutOrders()
            .Where(o => o.RentalItemId == rentalItemId)
            .SumAsync(o => (int?)o.Quantity, cancellationToken) ?? 0;
}
