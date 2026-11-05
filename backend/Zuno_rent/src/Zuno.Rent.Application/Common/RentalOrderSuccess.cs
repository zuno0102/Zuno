using Zuno.Rent.Domain.Entities;
using Zuno.Rent.Domain.Enums;

namespace Zuno.Rent.Application.Common;

/// <summary>
/// A rental that went well: the pieces came back and nothing is owed. Only such an order may be
/// rated, and only these count towards a business's successful rentals. Extra pieces added later are
/// part of their main order, so an add-on never counts on its own.
/// </summary>
internal static class RentalOrderSuccess
{
    /// <summary>Returned, a main order, and no balance left by <see cref="RentalMoney.Balance"/>.</summary>
    public static bool IsSuccessful(RentalOrderStatus status, Guid? parentOrderId, decimal amount, decimal netPaid) =>
        parentOrderId is null
        && status == RentalOrderStatus.Returned
        && RentalMoney.Balance(status, amount, netPaid) == 0;

    /// <summary>
    /// The successful main orders, worked out in the database: what was paid, less refunds, covers
    /// the order — the same sum as <see cref="RentalMoney.NetPaid"/> and the same rule as
    /// <see cref="IsSuccessful"/>.
    /// </summary>
    public static IQueryable<RentalOrder> SuccessfulOrders(this IRentDbContext dbContext) =>
        dbContext.RentalOrders.Where(o => o.ParentOrderId == null
            && o.Status == RentalOrderStatus.Returned
            && dbContext.RentalOrderPayments
                .Where(p => p.RentalOrderId == o.Id)
                .Sum(p => p.Kind == RentalPaymentKind.Refund ? -p.Amount : p.Amount) >= o.Amount);
}
