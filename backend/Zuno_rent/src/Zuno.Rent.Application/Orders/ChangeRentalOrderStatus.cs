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
}

public class ChangeRentalOrderStatusCommandValidator : AbstractValidator<ChangeRentalOrderStatusCommand>
{
    public ChangeRentalOrderStatusCommandValidator()
    {
        RuleFor(x => x.Id).NotEmpty();
        RuleFor(x => x.ToStatus)
            .Must(value => ChangeRentalOrderStatusCommandHandler.Parse(value).HasValue)
            .WithMessage("Choose what happens to the order next.");
    }
}

public class ChangeRentalOrderStatusCommandHandler(ICurrentUser currentUser, IRentDbContext dbContext)
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
            dbContext, request.Id, Parse(request.ToStatus)!.Value, currentUser.OwnerId(), RentalAudience.Business, cancellationToken);

    /// <summary>
    /// One step on an order, for whichever side may take it per the transition table — the business
    /// sends out and marks returned; a customer may cancel while the order is only booked.
    /// </summary>
    internal static async Task<RentalOrderDto> TakeStepAsync(
        IRentDbContext dbContext,
        Guid orderId,
        RentalOrderStatus to,
        Guid userId,
        RentalAudience audience,
        CancellationToken cancellationToken)
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

        order.Status = to;
        order.HoldUntil = null;
        RentalOrderHistory.Record(dbContext, order.Id, RentalOrderEventKind.StatusChanged, order.Quantity, userId, toStatus: to);
        await dbContext.SaveChangesAsync(cancellationToken);

        return await RentalOrderReader.ReadOneAsync(dbContext, order.Id, userId, cancellationToken, audience);
    }
}
