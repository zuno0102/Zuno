using FluentValidation;
using MediatR;
using Microsoft.EntityFrameworkCore;
using Zuno.Rent.Application.Common;
using Zuno.Rent.Application.Items;
using Zuno.Rent.Domain.Entities;
using Zuno.Rent.Domain.Enums;
using Zuno.Rent.Domain.Exceptions;

namespace Zuno.Rent.Application.Orders;

/// <summary>
/// What cancelling the business's order now would cost and give back — shown before the business
/// confirms. A business cancelling keeps nothing, so the customer gets back all they paid.
/// </summary>
public class GetRentalCancelQuoteQuery : IRequest<RentalCancelQuoteDto>
{
    public Guid Id { get; set; }
}

/// <summary>The customer's own order: the charge for cancelling it now, by the steps it was booked with.</summary>
public class GetMyRentalCancelQuoteQuery : IRequest<RentalCancelQuoteDto>
{
    public Guid Id { get; set; }
}

/// <summary>"Cancelling now: 2% charge (₹100), ₹4,900 back."</summary>
public class RentalCancelQuoteDto
{
    /// <summary>Whole days (hours for an hourly order) left before the start; 0 on the day itself.</summary>
    public int UnitsBefore { get; set; }

    /// <summary><c>Day</c> or <c>Hour</c>.</summary>
    public string Unit { get; set; } = string.Empty;

    public decimal Percent { get; set; }

    /// <summary><c>ByTimeLeft</c> or <c>PerRentalDay</c>: how [Percent] was reached.</summary>
    public string Basis { get; set; } = string.Empty;

    /// <summary>Days (hours, for an hourly order) the order is for — what a per-day charge counts.</summary>
    public int RentalUnits { get; set; }

    /// <summary>What the business keeps.</summary>
    public decimal Charge { get; set; }

    /// <summary>Paid so far, refunds taken off.</summary>
    public decimal Paid { get; set; }

    /// <summary>What goes back to the customer.</summary>
    public decimal Refund { get; set; }

    /// <summary>
    /// For the business cancelling a paid order: the ways the money can go back, one to be chosen in
    /// the cancel step. Empty when nothing would be owed back, or for the customer.
    /// </summary>
    public List<RentalRefundModeChoiceDto> RefundModes { get; set; } = [];
}

/// <summary>
/// The business chooses how a cancelled order's refund goes back: online, to the card or UPI the
/// customer paid with, or in hand. Each side is then told what to expect.
/// </summary>
public class SetRentalRefundModeCommand : IRequest<RentalOrderDto>
{
    /// <summary>From the route.</summary>
    public Guid Id { get; set; }

    /// <summary><c>Online</c> or <c>InHand</c>.</summary>
    public string Mode { get; set; } = string.Empty;
}

public class SetRentalRefundModeCommandValidator : AbstractValidator<SetRentalRefundModeCommand>
{
    public SetRentalRefundModeCommandValidator()
    {
        RuleFor(x => x.Id).NotEmpty();
        RuleFor(x => x.Mode)
            .Must(value => RentalCancellationHandlers.ParseMode(value).HasValue)
            .WithMessage("Choose how the refund goes back: online or in hand.");
    }
}

public class RentalCancellationHandlers(ICurrentUser currentUser, IRentDbContext dbContext, TimeProvider clock) :
    IRequestHandler<GetRentalCancelQuoteQuery, RentalCancelQuoteDto>,
    IRequestHandler<GetMyRentalCancelQuoteQuery, RentalCancelQuoteDto>,
    IRequestHandler<SetRentalRefundModeCommand, RentalOrderDto>
{
    internal static RentalRefundMode? ParseMode(string? value) =>
        !string.IsNullOrWhiteSpace(value)
        && !int.TryParse(value, out _)
        && Enum.TryParse<RentalRefundMode>(value, ignoreCase: true, out var parsed)
        && Enum.IsDefined(parsed)
            ? parsed
            : null;

    public Task<RentalCancelQuoteDto> Handle(GetRentalCancelQuoteQuery request, CancellationToken cancellationToken) =>
        QuoteAsync(request.Id, RentalAudience.Business, cancellationToken);

    public Task<RentalCancelQuoteDto> Handle(GetMyRentalCancelQuoteQuery request, CancellationToken cancellationToken) =>
        QuoteAsync(request.Id, RentalAudience.Customer, cancellationToken);

    public async Task<RentalOrderDto> Handle(SetRentalRefundModeCommand request, CancellationToken cancellationToken)
    {
        var ownerId = currentUser.OwnerId();
        await dbContext.EnsureOwnedOrderAsync(request.Id, ownerId, cancellationToken);

        var mode = ParseMode(request.Mode)!.Value;
        if (!await dbContext.RentalRefundModes.AnyAsync(m => m.Code == mode && m.IsActive, cancellationToken))
        {
            throw new DomainException("That way of refunding is not offered any more. Choose another.");
        }

        var order = await dbContext.RentalOrders.FirstAsync(o => o.Id == request.Id, cancellationToken);
        var payments = await dbContext.RentalOrderPayments
            .AsNoTracking()
            .Where(p => p.RentalOrderId == order.Id)
            .ToListAsync(cancellationToken);

        var owed = RentalMoney.RefundOwed(order.Status, RentalMoney.NetPaid(payments), order.CancellationCharge);
        if (owed <= 0)
        {
            throw new DomainException("Nothing is owed back on this order.");
        }

        // Once money has gone back one way, the way is settled.
        if (payments.Any(p => p.Kind == RentalPaymentKind.Refund))
        {
            throw new DomainException("Part of the refund has already gone back, so its method cannot change now.");
        }

        if (RentalMoney.RefundModeRefusal(mode, owed, RentalMoney.OnlinePaid(payments)) is { } refusal)
        {
            throw new DomainException(refusal);
        }

        if (order.RefundMode != mode)
        {
            order.RefundMode = mode;
            RentalOrderHistory.Record(
                dbContext, order.Id, RentalOrderEventKind.RefundModeChosen, order.Quantity, ownerId, amount: owed);
            await dbContext.SaveChangesAsync(cancellationToken);
        }

        return await RentalOrderReader.ReadOneAsync(dbContext, order.Id, ownerId, cancellationToken);
    }

    private async Task<RentalCancelQuoteDto> QuoteAsync(Guid orderId, RentalAudience audience, CancellationToken cancellationToken)
    {
        var userId = currentUser.OwnerId();
        await dbContext.EnsureOrderAccessAsync(orderId, userId, audience, cancellationToken);

        var order = await dbContext.RentalOrders.AsNoTracking().FirstAsync(o => o.Id == orderId, cancellationToken);
        var payments = await dbContext.RentalOrderPayments
            .AsNoTracking()
            .Where(p => p.RentalOrderId == order.Id)
            .ToListAsync(cancellationToken);
        var paid = RentalMoney.NetPaid(payments);
        var now = clock.GetUtcNow();

        // The same sums the cancel itself makes, so what is shown is what happens.
        var percent = audience == RentalAudience.Customer ? order.ChargePercentAt(now) : 0;
        var charge = RentalCancellation.Charge(order.Amount, percent, paid);
        var refund = Math.Max(0, paid - charge);
        var modes = audience == RentalAudience.Business && refund > 0
            ? await dbContext.RentalRefundModes.AsNoTracking()
                .Where(m => m.IsActive)
                .OrderBy(m => m.DisplayOrder)
                .ToListAsync(cancellationToken)
            : [];
        var onlinePaid = RentalMoney.OnlinePaid(payments);

        return new RentalCancelQuoteDto
        {
            UnitsBefore = RentalCancellation.UnitsBefore(order.PriceType, order.StartDate, now),
            Unit = RentalCancellation.UnitOf(order.PriceType),
            Basis = order.CancelChargeType.ToString(),
            RentalUnits = order.Units,
            Percent = percent,
            Charge = charge,
            Paid = paid,
            Refund = refund,
            RefundModes = modes
                .Select(m => new RentalRefundModeChoiceDto
                {
                    Code = m.Code.ToString(),
                    Name = m.Name,
                    Text = m.BusinessText,
                    DisabledReason = RentalMoney.RefundModeRefusal(m.Code, refund, onlinePaid),
                })
                .ToList(),
        };
    }
}
