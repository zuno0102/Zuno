using Microsoft.EntityFrameworkCore;
using Zuno.Rent.Domain.Entities;
using Zuno.Rent.Domain.Exceptions;

namespace Zuno.Rent.Application.Common;

/// <summary>
/// Which side of a rent order is asking: the business that rents the item out, or the customer who
/// rented it. Set by the route the request came in on — never by the request itself.
/// </summary>
public enum RentalAudience
{
    Business = 1,
    Customer = 2,
}

/// <summary>Who may open which rent order.</summary>
internal static class RentalOrderAccess
{
    /// <summary>
    /// Refuses an order that does not exist (404) or is not the caller's side of it (403), before
    /// anything is read or changed: the business that owns the item, or the customer who booked it.
    /// </summary>
    public static async Task EnsureOrderAccessAsync(
        this IRentDbContext dbContext,
        Guid orderId,
        Guid userId,
        RentalAudience audience,
        CancellationToken cancellationToken)
    {
        var parties = await dbContext.RentalOrders
            .Where(o => o.Id == orderId)
            .Select(o => new { o.OwnerUserId, o.CustomerUserId })
            .FirstOrDefaultAsync(cancellationToken)
            ?? throw new EntityNotFoundException(nameof(RentalOrder), orderId);

        var allowed = audience == RentalAudience.Business
            ? parties.OwnerUserId == userId
            : parties.CustomerUserId == userId;
        if (!allowed)
        {
            throw new ForbiddenException("This rent order is not yours.");
        }
    }

    /// <summary>The caller's orders: the business's own, or the customer's bookings.</summary>
    public static IQueryable<RentalOrder> OrdersOf(this IRentDbContext dbContext, Guid userId, RentalAudience audience) =>
        audience == RentalAudience.Business
            ? dbContext.RentalOrders.Where(o => o.OwnerUserId == userId)
            : dbContext.RentalOrders.Where(o => o.CustomerUserId == userId);
}
