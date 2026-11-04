using FluentValidation;
using MediatR;
using Microsoft.EntityFrameworkCore;
using Zuno.Rent.Application.Common;
using Zuno.Rent.Application.Items;
using Zuno.Rent.Domain.Enums;
using Zuno.Rent.Domain.Exceptions;

namespace Zuno.Rent.Application.Orders;

/// <summary>Moves a rent order one step — "Send out", "Mark returned", "Cancel order".</summary>
public class ChangeRentalOrderStatusCommand : IRequest<RentalOrderDto>
{
    /// <summary>From the route.</summary>
    public Guid Id { get; set; }

    /// <summary>The status to move to, e.g. <c>OnRent</c>.</summary>
    public string ToStatus { get; set; } = string.Empty;

    /// <summary>
    /// <c>Online</c> or <c>InHand</c>: how the money goes back when the business cancels an order the
    /// customer has paid for. Asked in the same step, so a refund is never left without a way back.
    /// </summary>
    public string? RefundMode { get; set; }
}

public class ChangeRentalOrderStatusCommandValidator : AbstractValidator<ChangeRentalOrderStatusCommand>
{
    public ChangeRentalOrderStatusCommandValidator()
    {
        RuleFor(x => x.Id).NotEmpty();
        RuleFor(x => x.ToStatus)
            .Must(value => ChangeRentalOrderStatusCommandHandler.Parse(value).HasValue)
            .WithMessage("Choose what happens to the order next.");
        RuleFor(x => x.RefundMode)
            .Must(value => RentalCancellationHandlers.ParseMode(value).HasValue)
            .When(x => !string.IsNullOrWhiteSpace(x.RefundMode))
            .WithMessage("Choose how the money goes back: online or in hand.");
    }
}

public class ChangeRentalOrderStatusCommandHandler(ICurrentUser currentUser, IRentDbContext dbContext, TimeProvider clock)
    : IRequestHandler<ChangeRentalOrderStatusCommand, RentalOrderDto>
{
    internal static RentalOrderStatus? Parse(string? value) =>
        !string.IsNullOrWhiteSpace(value)
        && !int.TryParse(value, out _)
        && Enum.TryParse<RentalOrderStatus>(value, ignoreCase: true, out var parsed)
        && Enum.IsDefined(parsed)
            ? parsed
            : null;

    public Task<RentalOrderDto> Handle(ChangeRentalOrderStatusCommand request, CancellationToken cancellationToken) =>
        TakeStepAsync(
            dbContext,
            clock,
            request.Id,
            Parse(request.ToStatus)!.Value,
            currentUser.OwnerId(),
            RentalAudience.Business,
            cancellationToken,
            RentalCancellationHandlers.ParseMode(request.RefundMode));

    /// <summary>
    /// One step on an order, for whichever side may take it per the transition table — the business
    /// sends out and marks returned; a customer may cancel while the order is only booked.
    /// </summary>
    internal static async Task<RentalOrderDto> TakeStepAsync(
        IRentDbContext dbContext,
        TimeProvider clock,
        Guid orderId,
        RentalOrderStatus to,
        Guid userId,
        RentalAudience audience,
        CancellationToken cancellationToken,
        RentalRefundMode? refundMode = null)
    {
        await dbContext.EnsureOrderAccessAsync(orderId, userId, audience, cancellationToken);

        var order = await dbContext.RentalOrders
            .Include(o => o.RentalItem)
            .FirstAsync(o => o.Id == orderId, cancellationToken);

        // Only a step the transition table offers from where the order is now, to this side.
        var step = await dbContext.RentalOrderTransitions
            .AsNoTracking()
            .FirstOrDefaultAsync(
                t => t.FromStatus == order.Status && t.ToStatus == to
                    && (audience == RentalAudience.Business ? t.BusinessMay : t.CustomerMay),
                cancellationToken)
            ?? throw new DomainException("That step is not possible for this order now. Refresh and try again.");

        if (step.RequiresPaid)
        {
            var due = RentalMoney.Balance(order.Status, order.Amount, await dbContext.NetPaidAsync(order.Id, cancellationToken));
            if (due > 0)
            {
                throw new DomainException(
                    $"{RentalMoney.Text(due)} is still due on this order. Collect it before \"{step.ActionLabel}\".");
            }
        }

        var target = await dbContext.RentalOrderStatuses.AsNoTracking().FirstAsync(s => s.Code == to, cancellationToken);
        var current = await dbContext.RentalOrderStatuses.AsNoTracking().FirstAsync(s => s.Code == order.Status, cancellationToken);

        // Sending pieces out needs them on hand: what the business owns minus what is already out.
        if (target.CountsAsOut && !current.CountsAsOut)
        {
            var inStock = order.RentalItem.QuantityOwned
                - await dbContext.QuantityOutAsync(order.RentalItemId, cancellationToken);
            if (inStock < order.Quantity)
            {
                throw new DomainException(
                    $"Only {Math.Max(0, inStock)} {order.RentalItem.Name} in stock; this order needs {order.Quantity}.");
            }
        }

        if (to == RentalOrderStatus.Cancelled)
        {
            // The charge follows who cancels and how early, against the steps kept on the order.
            var by = audience == RentalAudience.Business ? RentalMessageSenderRole.Business : RentalMessageSenderRole.Customer;
            var payments = await dbContext.RentalOrderPayments
                .AsNoTracking()
                .Where(p => p.RentalOrderId == order.Id)
                .ToListAsync(cancellationToken);
            var netPaid = RentalMoney.NetPaid(payments);
            order.Cancel(by, clock.GetUtcNow(), netPaid);

            // The business cancelling an order the customer paid for says, in the same step, how the
            // money goes back — so it is never left owed with no way back.
            var owed = RentalMoney.RefundOwed(order.Status, netPaid, order.CancellationCharge);
            if (audience == RentalAudience.Business && owed > 0)
            {
                var mode = refundMode
                    ?? throw new DomainException($"{RentalMoney.Text(owed)} was paid. Choose how it goes back: online or in hand.");
                if (!await dbContext.RentalRefundModes.AnyAsync(m => m.Code == mode && m.IsActive, cancellationToken))
                {
                    throw new DomainException("That way of refunding is not offered any more. Choose another.");
                }

                if (RentalMoney.RefundModeRefusal(mode, owed, RentalMoney.OnlinePaid(payments)) is { } refusal)
                {
                    throw new DomainException(refusal);
                }

                order.RefundMode = mode;
                RentalOrderHistory.Record(
                    dbContext, order.Id, RentalOrderEventKind.RefundModeChosen, order.Quantity, userId, amount: owed);
            }
        }
        else
        {
            order.Status = to;
            order.HoldUntil = null;
        }

        RentalOrderHistory.Record(dbContext, order.Id, RentalOrderEventKind.StatusChanged, order.Quantity, userId, toStatus: to);
        if (order.CancellationCharge > 0)
        {
            RentalOrderHistory.Record(
                dbContext, order.Id, RentalOrderEventKind.CancellationCharged, order.Quantity, userId, amount: order.CancellationCharge);
        }

        await dbContext.SaveChangesAsync(cancellationToken);

        return await RentalOrderReader.ReadOneAsync(dbContext, order.Id, userId, cancellationToken, audience);
    }
}
