using System.Globalization;
using Microsoft.EntityFrameworkCore;
using Zuno.Rent.Application.Orders;
using Zuno.Rent.Domain.Entities;
using Zuno.Rent.Domain.Enums;

namespace Zuno.Rent.Application.Common;

/// <summary>
/// The money on a rent order, read one way everywhere: paid is the payments minus the refunds, due is
/// what the order costs minus that, and the payment standing follows from both. Nothing here is
/// stored twice — the payment lines are the record.
/// </summary>
internal static class RentalMoney
{
    /// <summary>Payments in, minus refunds out.</summary>
    public static decimal NetPaid(IEnumerable<RentalOrderPayment> payments) =>
        payments.Sum(p => p.Kind == RentalPaymentKind.Refund ? -p.Amount : p.Amount);

    public static async Task<decimal> NetPaidAsync(this IRentDbContext dbContext, Guid orderId, CancellationToken cancellationToken) =>
        await dbContext.RentalOrderPayments
            .Where(p => p.RentalOrderId == orderId)
            .SumAsync(p => p.Kind == RentalPaymentKind.Refund ? -p.Amount : p.Amount, cancellationToken);

    /// <summary>What is still to be paid: nothing on a cancelled order, never below zero.</summary>
    public static decimal Balance(RentalOrderStatus status, decimal amount, decimal netPaid) =>
        status == RentalOrderStatus.Cancelled ? 0 : Math.Max(0, amount - netPaid);

    /// <summary>
    /// What a cancelled order still owes the customer: what they paid, less refunds already given and
    /// the cancellation charge the business keeps. Nothing on an order that is not cancelled.
    /// </summary>
    public static decimal RefundOwed(RentalOrderStatus status, decimal netPaid, decimal cancellationCharge) =>
        status == RentalOrderStatus.Cancelled ? Math.Max(0, netPaid - cancellationCharge) : 0;

    /// <summary>Paid through the gateway, less refunds already sent back that way — all an online refund can return.</summary>
    public static decimal OnlinePaid(IEnumerable<RentalOrderPayment> payments) =>
        NetPaid(payments.Where(p => p.Method == RentalPaymentMethod.Online));

    /// <summary>
    /// Why a refund cannot go back this way; null when it can. Online goes back to the card or UPI
    /// the customer paid with, so it can return no more than they paid online.
    /// </summary>
    public static string? RefundModeRefusal(RentalRefundMode mode, decimal refundOwed, decimal onlinePaid) =>
        mode == RentalRefundMode.Online && onlinePaid < refundOwed
            ? onlinePaid <= 0
                ? "The customer paid in cash or by UPI, so give the refund in hand."
                : $"Only {Text(onlinePaid)} was paid online, so give the refund in hand."
            : null;

    /// <summary>
    /// Where the order stands with money; null when there is nothing to say (a cancelled order that
    /// never took any, or an old order with no price).
    /// </summary>
    public static RentalPaymentStatus? StatusOf(
        RentalOrderStatus status,
        decimal amount,
        decimal advanceDue,
        decimal netPaid,
        bool anyRefund,
        decimal cancellationCharge = 0)
    {
        if (status == RentalOrderStatus.Cancelled)
        {
            return RefundOwed(status, netPaid, cancellationCharge) > 0 ? RentalPaymentStatus.RefundDue
                : anyRefund ? RentalPaymentStatus.Refunded
                : netPaid > 0 ? RentalPaymentStatus.ChargeKept
                : null;
        }

        if (status == RentalOrderStatus.AwaitingAdvance && netPaid < advanceDue)
        {
            return RentalPaymentStatus.AdvanceDue;
        }

        if (amount <= 0)
        {
            return null;
        }

        if (netPaid >= amount)
        {
            return RentalPaymentStatus.Paid;
        }

        if (netPaid <= 0)
        {
            return RentalPaymentStatus.Unpaid;
        }

        return advanceDue > 0 && netPaid == advanceDue ? RentalPaymentStatus.AdvancePaid : RentalPaymentStatus.PartPaid;
    }

    /// <summary>Adds a payment line and the history step that says it, in the caller's save.</summary>
    public static void Record(
        IRentDbContext dbContext,
        RentalOrder order,
        RentalPaymentKind kind,
        RentalPaymentMethod method,
        decimal amount,
        Guid userId,
        RentalMessageSenderRole role,
        string? providerOrderId = null,
        string? providerPaymentId = null,
        string? reference = null,
        string? payeeUpiId = null)
    {
        dbContext.RentalOrderPayments.Add(new RentalOrderPayment
        {
            RentalOrderId = order.Id,
            Kind = kind,
            Method = method,
            Amount = amount,
            ProviderOrderId = providerOrderId,
            ProviderPaymentId = providerPaymentId,
            Reference = reference,
            PayeeUpiId = payeeUpiId,
            RecordedByUserId = userId,
            RecordedByRole = role,
        });

        var step = kind switch
        {
            RentalPaymentKind.Advance => RentalOrderEventKind.AdvancePaid,
            RentalPaymentKind.Refund => RentalOrderEventKind.Refunded,
            _ => RentalOrderEventKind.PaymentReceived,
        };
        RentalOrderHistory.Record(dbContext, order.Id, step, order.Quantity, userId, amount: amount, method: method);
    }

    /// <summary>"₹1,500" or "₹12.50" — how amounts read in messages.</summary>
    public static string Text(decimal amount) =>
        "₹" + amount.ToString(amount == decimal.Truncate(amount) ? "#,##0" : "#,##0.00", CultureInfo.InvariantCulture);
}
