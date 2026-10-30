using Microsoft.EntityFrameworkCore;
using Zuno.Rent.Application.Common;
using Zuno.Rent.Application.Items;
using Zuno.Rent.Domain.Entities;
using Zuno.Rent.Domain.Enums;

namespace Zuno.Rent.Application.Orders;

/// <summary>
/// Reads rent orders the one way every screen shows them — business or customer: with the item's
/// name, the status name and colour from the status table, the steps this side may take from the
/// transition table, and the other side's unread messages.
/// </summary>
internal static class RentalOrderReader
{
    /// <summary>One page of [orders], newest first.</summary>
    public static async Task<RentalOrderPageDto> ReadPageAsync(
        IRentDbContext dbContext,
        IQueryable<RentalOrder> orders,
        int page,
        int pageSize,
        CancellationToken cancellationToken,
        RentalAudience audience = RentalAudience.Business)
    {
        var totalCount = await orders.CountAsync(cancellationToken);
        var items = totalCount == 0
            ? []
            : await ReadAsync(
                dbContext,
                orders
                    .OrderByDescending(o => o.StartDate)
                    .ThenByDescending(o => o.CreatedDate)
                    .Skip((page - 1) * pageSize)
                    .Take(pageSize),
                audience,
                cancellationToken);

        return new RentalOrderPageDto { Items = items, Page = page, PageSize = pageSize, TotalCount = totalCount };
    }

    /// <summary>The caller's order, or NotFound / Forbidden.</summary>
    public static async Task<RentalOrderDto> ReadOneAsync(
        IRentDbContext dbContext,
        Guid orderId,
        Guid userId,
        CancellationToken cancellationToken,
        RentalAudience audience = RentalAudience.Business)
    {
        await dbContext.EnsureOrderAccessAsync(orderId, userId, audience, cancellationToken);
        return (await ReadAsync(dbContext, dbContext.RentalOrders.Where(o => o.Id == orderId), audience, cancellationToken)).Single();
    }

    /// <summary>Refuses an order that does not exist or is another business's, before anything is read or changed.</summary>
    public static Task EnsureOwnedOrderAsync(
        this IRentDbContext dbContext, Guid orderId, Guid ownerUserId, CancellationToken cancellationToken) =>
        dbContext.EnsureOrderAccessAsync(orderId, ownerUserId, RentalAudience.Business, cancellationToken);

    private static async Task<List<RentalOrderDto>> ReadAsync(
        IRentDbContext dbContext, IQueryable<RentalOrder> orders, RentalAudience audience, CancellationToken cancellationToken)
    {
        // Small reference tables, read whole: a handful of rows each.
        var statuses = await dbContext.RentalOrderStatuses.AsNoTracking().ToDictionaryAsync(s => s.Code, cancellationToken);
        var transitions = (await dbContext.RentalOrderTransitions.AsNoTracking().ToListAsync(cancellationToken))
            .Where(t => audience == RentalAudience.Business ? t.BusinessMay : t.CustomerMay)
            .OrderBy(t => t.DisplayOrder)
            .ToLookup(t => t.FromStatus);

        var paymentStatuses = await dbContext.RentalPaymentStatuses.AsNoTracking().ToDictionaryAsync(s => s.Code, cancellationToken);
        var methods = await dbContext.RentalPaymentMethods.AsNoTracking().ToDictionaryAsync(m => m.Code, m => m.Name, cancellationToken);

        // Unread means what the other side wrote that this side has not opened.
        var otherSide = audience == RentalAudience.Business ? RentalMessageSenderRole.Customer : RentalMessageSenderRole.Business;

        var rows = await orders
            .AsNoTracking()
            .Select(o => new
            {
                o.Id,
                o.RentalItemId,
                ItemName = o.RentalItem.Name,
                BusinessName = dbContext.RentalBusinesses
                    .Where(b => b.OwnerUserId == o.OwnerUserId)
                    .Select(b => b.Name)
                    .FirstOrDefault(),
                UpiId = dbContext.RentalBusinesses
                    .Where(b => b.OwnerUserId == o.OwnerUserId)
                    .Select(b => b.UpiId)
                    .FirstOrDefault(),
                o.PriceType,
                o.UnitPrice,
                o.Units,
                o.Amount,
                o.AdvanceDue,
                o.HoldUntil,
                o.CustomerName,
                o.CustomerPhone,
                o.Quantity,
                o.StartDate,
                o.EndDate,
                o.DeliveryAddress,
                District = o.District == null ? null : o.District.Name,
                o.Status,
                o.Source,
                Unread = dbContext.RentalOrderMessages.Count(m =>
                    m.RentalOrderId == o.Id && m.SenderRole == otherSide && m.ReadAt == null),
                o.ParentOrderId,
                AddOns = dbContext.RentalOrders
                    .Where(a => a.ParentOrderId == o.Id)
                    .OrderBy(a => a.CreatedDate)
                    .Select(a => new { a.Id, a.Quantity, a.Status })
                    .ToList(),
                Answers = dbContext.RentalOrderAnswers
                    .Where(a => a.RentalOrderId == o.Id)
                    .OrderBy(a => a.CreatedDate)
                    .Select(a => new RentalOrderAnswerDto { Prompt = a.Prompt, Answer = a.Answer })
                    .ToList(),
            })
            .ToListAsync(cancellationToken);

        // Every order's payments in one read, then grouped.
        var ids = rows.Select(r => r.Id).ToList();
        var payments = (await dbContext.RentalOrderPayments
                .AsNoTracking()
                .Where(p => ids.Contains(p.RentalOrderId))
                .OrderBy(p => p.CreatedDate)
                .ToListAsync(cancellationToken))
            .ToLookup(p => p.RentalOrderId);

        return rows.Select(o =>
        {
            statuses.TryGetValue(o.Status, out var status);
            var lines = payments[o.Id].ToList();
            var paid = RentalMoney.NetPaid(lines);
            var balance = RentalMoney.Balance(o.Status, o.Amount, paid);
            var paymentStatus = RentalMoney.StatusOf(
                o.Status, o.Amount, o.AdvanceDue, paid, lines.Any(p => p.Kind == RentalPaymentKind.Refund));
            var paymentOption = paymentStatus is { } ps ? paymentStatuses.GetValueOrDefault(ps) : null;
            var awaiting = o.Status == RentalOrderStatus.AwaitingAdvance;
            var open = o.Status is not (RentalOrderStatus.Cancelled or RentalOrderStatus.Returned);
            return new RentalOrderDto
            {
                Id = o.Id,
                RentalItemId = o.RentalItemId,
                ItemName = o.ItemName,
                BusinessName = o.BusinessName,
                CustomerName = o.CustomerName,
                CustomerPhone = o.CustomerPhone,
                Quantity = o.Quantity,
                StartDate = o.StartDate,
                EndDate = o.EndDate,
                DeliveryAddress = o.DeliveryAddress,
                DistrictName = o.District,
                Status = o.Status.ToString(),
                StatusName = status?.Name ?? o.Status.ToString(),
                StatusTone = status?.Tone ?? "waiting",
                IsOut = status?.CountsAsOut ?? false,
                Source = o.Source.ToString(),
                UnreadMessages = o.Unread,
                Actions = transitions[o.Status]
                    .Select(t => new RentalOrderActionDto
                    {
                        ToStatus = t.ToStatus.ToString(),
                        Label = t.ActionLabel,
                        ConfirmFirst = t.ConfirmFirst,
                        DisabledReason = t.RequiresPaid && balance > 0
                            ? $"Collect {RentalMoney.Text(balance)} first"
                            : null,
                    })
                    .ToList(),
                ParentOrderId = o.ParentOrderId,
                AddOns = o.AddOns
                    .Select(a => new RentalOrderAddOnDto
                    {
                        Id = a.Id,
                        Quantity = a.Quantity,
                        StatusName = statuses.GetValueOrDefault(a.Status)?.Name ?? a.Status.ToString(),
                        StatusTone = statuses.GetValueOrDefault(a.Status)?.Tone ?? "waiting",
                    })
                    .ToList(),
                Answers = o.Answers,

                // Only the business adds pieces; a customer asks in a message.
                CanAddPieces = audience == RentalAudience.Business
                    && !awaiting
                    && status is { } s && (s.CountsAsBooked || s.CountsAsOut),

                PriceType = o.PriceType.ToString(),
                UnitPrice = o.UnitPrice,
                Units = o.Units,
                Amount = o.Amount,
                AdvanceDue = o.AdvanceDue,
                Paid = paid,
                Balance = balance,
                PaymentStatus = paymentStatus?.ToString(),
                PaymentStatusName = paymentOption?.Name ?? paymentStatus?.ToString(),
                PaymentStatusTone = paymentOption?.Tone,
                Payments = lines
                    .Select(p => new RentalOrderPaymentDto
                    {
                        Id = p.Id,
                        At = p.CreatedDate,
                        Kind = p.Kind.ToString(),
                        MethodName = methods.GetValueOrDefault(p.Method) ?? p.Method.ToString(),
                        Amount = p.Amount,
                    })
                    .ToList(),
                HoldUntil = awaiting ? o.HoldUntil : null,
                PayNowAmount = awaiting ? Math.Max(0, o.AdvanceDue - paid) : open ? balance : 0,
                CanCollect = audience == RentalAudience.Business && open && balance > 0,
                CanRefund = audience == RentalAudience.Business && o.Status == RentalOrderStatus.Cancelled && paid > 0,
                CanPayOnline = audience == RentalAudience.Customer && open && balance > 0,

                // The QR is the business's to show; a customer pays the business in front of them.
                UpiId = audience == RentalAudience.Business ? o.UpiId : null,
            };
        }).ToList();
    }
}
