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
/// The business records money taken for an order — cash, or a UPI payment to its QR — or money given
/// back on a cancelled one. Never more than is due, or than was paid.
/// </summary>
public class RecordRentalPaymentCommand : IRequest<RentalOrderDto>
{
    /// <summary>From the route.</summary>
    public Guid Id { get; set; }

    /// <summary><c>Cash</c> or <c>UpiQr</c>.</summary>
    public string Method { get; set; } = string.Empty;

    public decimal Amount { get; set; }

    /// <summary>Money given back rather than taken in.</summary>
    public bool IsRefund { get; set; }

    /// <summary>The UPI transaction reference the UPI app reported; only with UPI.</summary>
    public string? Reference { get; set; }

    /// <summary>The customer's UPI ID a refund was paid to; only with UPI.</summary>
    public string? PayeeUpiId { get; set; }
}

/// <summary>The customer starts paying online — the advance while it is awaited, otherwise what is due.</summary>
public class StartRentalPaymentCommand : IRequest<RentalCheckoutDto>
{
    public Guid Id { get; set; }
}

/// <summary>What the app opens the payment window with.</summary>
public class RentalCheckoutDto
{
    public string ProviderOrderId { get; set; } = string.Empty;

    /// <summary>The gateway's public key.</summary>
    public string KeyId { get; set; } = string.Empty;

    public decimal Amount { get; set; }

    /// <summary>"Advance for 300 Plastic chair".</summary>
    public string Description { get; set; } = string.Empty;

    /// <summary>Development only: no money moves, so the app confirms without opening the window.</summary>
    public bool NothingToCollect { get; set; }
}

/// <summary>
/// The customer's payment came back from the gateway. Counted only when its signature checks out,
/// and only once, however often the app sends it.
/// </summary>
public class CompleteRentalPaymentCommand : IRequest<RentalOrderDto>
{
    public Guid Id { get; set; }

    public string ProviderOrderId { get; set; } = string.Empty;

    public string PaymentId { get; set; } = string.Empty;

    public string Signature { get; set; } = string.Empty;
}

/// <summary>
/// The business's payment details: the UPI ID its order QR is made from. It is set on the business's
/// Service profile, so reading it first refreshes from there — an ID just added shows at once.
/// </summary>
public class GetRentalPaymentSettingsQuery : IRequest<RentalPaymentSettingsDto>;

public class RentalPaymentSettingsDto
{
    public string? UpiId { get; set; }
}

/// <summary>
/// Kept for the app before 1.10.1, which saves the UPI ID in Rent. Newer apps save it on the Service
/// profile, and an ID there always wins over this one at the next refresh.
/// </summary>
public class UpdateRentalPaymentSettingsCommand : IRequest<RentalPaymentSettingsDto>
{
    /// <summary>E.g. <c>joyrentals@okhdfcbank</c>; empty removes it.</summary>
    public string? UpiId { get; set; }
}

public class UpdateRentalPaymentSettingsCommandValidator : AbstractValidator<UpdateRentalPaymentSettingsCommand>
{
    public UpdateRentalPaymentSettingsCommandValidator()
    {
        RuleFor(x => x.UpiId)
            .MaximumLength(RentalPaymentFields.UpiIdMaxLength)
            .Matches(RentalPaymentFields.UpiIdPattern)
            .WithMessage("Enter a UPI ID like name@bank.")
            .When(x => !string.IsNullOrWhiteSpace(x.UpiId));
    }
}

/// <summary>The words for advances and payment methods, for the item form and the collect sheet.</summary>
public class GetRentalPaymentOptionsQuery : IRequest<RentalPaymentOptionsDto>;

public class RentalPaymentOptionsDto
{
    public List<RentalOptionDto> AdvanceTypes { get; set; } = [];

    /// <summary>The ways a business may record money taken, in order — UPI QR first.</summary>
    public List<RentalOptionDto> Methods { get; set; } = [];

    /// <summary>The ways a cancellation charge can be worked out, for the item form.</summary>
    public List<RentalOptionDto> CancelChargeTypes { get; set; } = [];
}

public class RentalOptionDto
{
    public string Code { get; set; } = string.Empty;

    public string Name { get; set; } = string.Empty;

    public string Detail { get; set; } = string.Empty;
}

/// <summary>
/// Lets go of app bookings whose advance was not paid in time: cancelled, with a history step, so
/// their pieces show as free in every list. Run by the lapse job every minute.
/// </summary>
public class LapseRentalAdvancesCommand : IRequest<int>
{
    public int Take { get; set; } = 100;
}

public class RecordRentalPaymentCommandValidator : AbstractValidator<RecordRentalPaymentCommand>
{
    public RecordRentalPaymentCommandValidator()
    {
        RuleFor(x => x.Id).NotEmpty();
        RuleFor(x => x.Method)
            .Must(value => RentalPayments.ParseMethod(value).HasValue)
            .WithMessage("Say how it was paid: cash or UPI QR.");
        RuleFor(x => x.Amount)
            .GreaterThan(0).WithMessage("Enter the amount.")
            .PrecisionScale(14, 2, ignoreTrailingZeros: true).WithMessage("Enter the amount in rupees and paise.");

        RuleFor(x => x.Reference)
            .Matches(RentalPaymentFields.ReferencePattern)
            .WithMessage("Enter the UPI reference as the UPI app shows it: letters and digits.")
            .When(x => !string.IsNullOrWhiteSpace(x.Reference));
        RuleFor(x => x.PayeeUpiId)
            .MaximumLength(RentalPaymentFields.UpiIdMaxLength)
            .Matches(RentalPaymentFields.UpiIdPattern)
            .WithMessage("Enter a UPI ID like name@bank.")
            .When(x => !string.IsNullOrWhiteSpace(x.PayeeUpiId));
        RuleFor(x => x)
            .Must(x => RentalPayments.ParseMethod(x.Method) == RentalPaymentMethod.UpiQr)
            .When(x => !string.IsNullOrWhiteSpace(x.Reference) || !string.IsNullOrWhiteSpace(x.PayeeUpiId))
            .WithName("Reference")
            .WithMessage("A UPI reference goes with a UPI payment, not cash.");
    }
}

public class CompleteRentalPaymentCommandValidator : AbstractValidator<CompleteRentalPaymentCommand>
{
    public CompleteRentalPaymentCommandValidator()
    {
        RuleFor(x => x.Id).NotEmpty();
        RuleFor(x => x.ProviderOrderId).NotEmpty().MaximumLength(100);
        RuleFor(x => x.PaymentId).NotEmpty().MaximumLength(100);
        RuleFor(x => x.Signature).NotEmpty().MaximumLength(200);
    }
}

/// <summary>Reads payment methods, shared by the offline order and the payment commands.</summary>
public static class RentalPayments
{
    /// <summary>The method, or null when it is not one this API knows.</summary>
    public static RentalPaymentMethod? ParseMethod(string? value) =>
        !string.IsNullOrWhiteSpace(value)
        && !int.TryParse(value, out _)
        && Enum.TryParse<RentalPaymentMethod>(value, ignoreCase: true, out var parsed)
        && Enum.IsDefined(parsed)
            ? parsed
            : null;

    /// <summary>Whether the method table lets a business record money taken this way — not "online", which only the gateway proves.</summary>
    internal static Task<bool> BusinessMayRecordAsync(IRentDbContext dbContext, RentalPaymentMethod method, CancellationToken cancellationToken) =>
        dbContext.RentalPaymentMethods.AnyAsync(m => m.Code == method && m.BusinessMayRecord, cancellationToken);
}

public class RentalPaymentHandlers(
    ICurrentUser currentUser,
    IRentDbContext dbContext,
    IRentPaymentGateway gateway,
    TimeProvider clock) :
    IRequestHandler<RecordRentalPaymentCommand, RentalOrderDto>,
    IRequestHandler<StartRentalPaymentCommand, RentalCheckoutDto>,
    IRequestHandler<CompleteRentalPaymentCommand, RentalOrderDto>,
    IRequestHandler<GetRentalPaymentOptionsQuery, RentalPaymentOptionsDto>,
    IRequestHandler<LapseRentalAdvancesCommand, int>
{
    public async Task<RentalOrderDto> Handle(RecordRentalPaymentCommand request, CancellationToken cancellationToken)
    {
        var ownerId = currentUser.OwnerId();
        await dbContext.EnsureOwnedOrderAsync(request.Id, ownerId, cancellationToken);

        var method = RentalPayments.ParseMethod(request.Method)!.Value;
        if (!await RentalPayments.BusinessMayRecordAsync(dbContext, method, cancellationToken))
        {
            throw new DomainException("Online payments are recorded by the app itself. Choose cash or UPI QR.");
        }

        var itemId = await dbContext.RentalOrders.Where(o => o.Id == request.Id).Select(o => o.RentalItemId).FirstAsync(cancellationToken);

        // Under the item's lock: taking an awaited advance can book the pieces, and the lapse job
        // must not let the same order go at that moment.
        await dbContext.WithItemLockAsync(itemId, async () =>
        {
            var order = await dbContext.RentalOrders.Include(o => o.RentalItem).FirstAsync(o => o.Id == request.Id, cancellationToken);
            var paid = await dbContext.NetPaidAsync(order.Id, cancellationToken);

            if (request.IsRefund)
            {
                if (order.Status != RentalOrderStatus.Cancelled)
                {
                    throw new DomainException("Money is given back only on a cancelled order.");
                }

                if (order.RefundMode == RentalRefundMode.Online)
                {
                    throw new DomainException("This refund goes back online. Change it to in hand to give it back yourself.");
                }

                // What the customer paid, less the cancellation charge the business keeps.
                var owed = RentalMoney.RefundOwed(order.Status, paid, order.CancellationCharge);
                if (request.Amount > owed)
                {
                    throw new DomainException(owed <= 0
                        ? "Nothing is owed back on this order."
                        : $"Only {RentalMoney.Text(owed)} is owed back on this order.");
                }

                // Giving it back by hand settles how it goes back.
                order.RefundMode ??= RentalRefundMode.InHand;
                RentalMoney.Record(
                    dbContext, order, RentalPaymentKind.Refund, method, request.Amount, ownerId, RentalMessageSenderRole.Business,
                    reference: Clean(request.Reference), payeeUpiId: Clean(request.PayeeUpiId));
                await dbContext.SaveChangesAsync(cancellationToken);
                return true;
            }

            var due = RentalMoney.Balance(order.Status, order.Amount, paid);
            if (order.Status is RentalOrderStatus.Cancelled or RentalOrderStatus.Returned || due <= 0)
            {
                throw new DomainException("Nothing is due on this order.");
            }

            if (request.Amount > due)
            {
                throw new DomainException($"Only {RentalMoney.Text(due)} is due on this order.");
            }

            // Money towards an advance still awaited counts as the advance — the customer paid at the counter.
            var kind = paid < order.AdvanceDue ? RentalPaymentKind.Advance : RentalPaymentKind.Balance;
            RentalMoney.Record(
                dbContext, order, kind, method, request.Amount, ownerId, RentalMessageSenderRole.Business,
                reference: Clean(request.Reference));
            await BookIfAdvancePaidAsync(order, paid + request.Amount, ownerId, cancellationToken);
            await dbContext.SaveChangesAsync(cancellationToken);
            return true;
        }, cancellationToken);

        return await RentalOrderReader.ReadOneAsync(dbContext, request.Id, ownerId, cancellationToken);
    }

    private static string? Clean(string? value) => string.IsNullOrWhiteSpace(value) ? null : value.Trim();

    public async Task<RentalCheckoutDto> Handle(StartRentalPaymentCommand request, CancellationToken cancellationToken)
    {
        var customerId = currentUser.OwnerId();
        await dbContext.EnsureOrderAccessAsync(request.Id, customerId, RentalAudience.Customer, cancellationToken);

        if (!gateway.IsReady)
        {
            throw new DomainException("Online payment is not available just now. Pay the business directly — cash or UPI.");
        }

        var order = await dbContext.RentalOrders.AsNoTracking().Include(o => o.RentalItem).FirstAsync(o => o.Id == request.Id, cancellationToken);
        var paid = await dbContext.NetPaidAsync(order.Id, cancellationToken);
        var awaiting = order.Status == RentalOrderStatus.AwaitingAdvance;

        if (awaiting && order.HoldUntil <= clock.GetUtcNow())
        {
            throw new DomainException("The time to pay the advance has passed, so the pieces were let go. Book again.");
        }

        var amount = awaiting
            ? order.AdvanceDue - paid
            : order.Status is RentalOrderStatus.Cancelled or RentalOrderStatus.Returned ? 0 : RentalMoney.Balance(order.Status, order.Amount, paid);
        if (amount <= 0)
        {
            throw new DomainException("Nothing is due on this order.");
        }

        var kind = awaiting ? RentalPaymentKind.Advance : RentalPaymentKind.Balance;
        var description = $"{(awaiting ? "Advance" : "Payment")} for {order.Quantity} {order.RentalItem.Name}";

        // One gateway order per attempt; the receipt keeps a retried request from raising a second one.
        var attempt = await dbContext.RentalPaymentCheckouts.CountAsync(c => c.RentalOrderId == order.Id, cancellationToken);
        var providerOrderId = await gateway.CreateOrderAsync(amount, $"{order.Id:N}-{attempt + 1}", description, cancellationToken);

        dbContext.RentalPaymentCheckouts.Add(new RentalPaymentCheckout
        {
            RentalOrderId = order.Id,
            Kind = kind,
            Amount = amount,
            ProviderOrderId = providerOrderId,
        });
        await dbContext.SaveChangesAsync(cancellationToken);

        return new RentalCheckoutDto
        {
            ProviderOrderId = providerOrderId,
            KeyId = gateway.KeyId,
            Amount = amount,
            Description = description,
            NothingToCollect = gateway.IsSimulated,
        };
    }

    public async Task<RentalOrderDto> Handle(CompleteRentalPaymentCommand request, CancellationToken cancellationToken)
    {
        var customerId = currentUser.OwnerId();
        await dbContext.EnsureOrderAccessAsync(request.Id, customerId, RentalAudience.Customer, cancellationToken);

        var checkout = await dbContext.RentalPaymentCheckouts
            .AsNoTracking()
            .FirstOrDefaultAsync(c => c.ProviderOrderId == request.ProviderOrderId && c.RentalOrderId == request.Id, cancellationToken)
            ?? throw new DomainException("That payment is not for this order.");

        if (!gateway.VerifySignature(checkout.ProviderOrderId, request.PaymentId, request.Signature))
        {
            throw new DomainException("We could not confirm this payment. If money left your account, show the payment to the business.");
        }

        var itemId = await dbContext.RentalOrders.Where(o => o.Id == request.Id).Select(o => o.RentalItemId).FirstAsync(cancellationToken);
        await dbContext.WithItemLockAsync(itemId, async () =>
        {
            // Sent twice — a retry, or the window reporting again — it counts once.
            var counted = await dbContext.RentalPaymentCheckouts.AnyAsync(c => c.Id == checkout.Id && c.CompletedAt != null, cancellationToken)
                || await dbContext.RentalOrderPayments.AnyAsync(p => p.ProviderPaymentId == request.PaymentId, cancellationToken);
            if (counted)
            {
                return true;
            }

            var order = await dbContext.RentalOrders.Include(o => o.RentalItem).FirstAsync(o => o.Id == request.Id, cancellationToken);
            var paid = await dbContext.NetPaidAsync(order.Id, cancellationToken);

            // The money moved, so it is recorded whatever the order's state — a lapsed booking shows it as a refund due.
            RentalMoney.Record(
                dbContext,
                order,
                checkout.Kind,
                RentalPaymentMethod.Online,
                checkout.Amount,
                customerId,
                RentalMessageSenderRole.Customer,
                checkout.ProviderOrderId,
                request.PaymentId);

            var tracked = await dbContext.RentalPaymentCheckouts.FirstAsync(c => c.Id == checkout.Id, cancellationToken);
            tracked.CompletedAt = clock.GetUtcNow();

            await BookIfAdvancePaidAsync(order, paid + checkout.Amount, customerId, cancellationToken);
            await dbContext.SaveChangesAsync(cancellationToken);
            return true;
        }, cancellationToken);

        return await RentalOrderReader.ReadOneAsync(dbContext, request.Id, customerId, cancellationToken, RentalAudience.Customer);
    }

    public async Task<RentalPaymentOptionsDto> Handle(GetRentalPaymentOptionsQuery request, CancellationToken cancellationToken)
    {
        var advanceTypes = await dbContext.RentalAdvanceTypes.AsNoTracking()
            .Where(a => a.IsActive)
            .OrderBy(a => a.DisplayOrder)
            .ToListAsync(cancellationToken);
        var methods = await dbContext.RentalPaymentMethods.AsNoTracking()
            .Where(m => m.BusinessMayRecord)
            .OrderBy(m => m.DisplayOrder)
            .ToListAsync(cancellationToken);
        var chargeTypes = await dbContext.RentalCancelChargeTypes.AsNoTracking()
            .Where(c => c.IsActive)
            .OrderBy(c => c.DisplayOrder)
            .ToListAsync(cancellationToken);

        // Mapped after the read: codes go out by name ("PerPiece"), which the database cannot write.
        return new RentalPaymentOptionsDto
        {
            AdvanceTypes = advanceTypes.Select(a => new RentalOptionDto { Code = a.Code.ToString(), Name = a.Name, Detail = a.Detail }).ToList(),
            Methods = methods.Select(m => new RentalOptionDto { Code = m.Code.ToString(), Name = m.Name }).ToList(),
            CancelChargeTypes = chargeTypes.Select(c => new RentalOptionDto { Code = c.Code.ToString(), Name = c.Name, Detail = c.Detail }).ToList(),
        };
    }

    public async Task<int> Handle(LapseRentalAdvancesCommand request, CancellationToken cancellationToken)
    {
        var now = clock.GetUtcNow();
        var lapsed = await dbContext.RentalOrders
            .AsNoTracking()
            .Where(o => o.Status == RentalOrderStatus.AwaitingAdvance && o.HoldUntil != null && o.HoldUntil <= now)
            .OrderBy(o => o.HoldUntil)
            .Select(o => new { o.Id, o.RentalItemId })
            .Take(request.Take)
            .ToListAsync(cancellationToken);

        var count = 0;
        foreach (var candidate in lapsed)
        {
            var done = await dbContext.WithItemLockAsync(candidate.RentalItemId, async () =>
            {
                // Looked at again under the lock: the advance may have come in a moment ago.
                var order = await dbContext.RentalOrders.FirstAsync(o => o.Id == candidate.Id, cancellationToken);
                if (order.Status != RentalOrderStatus.AwaitingAdvance || order.HoldUntil > now)
                {
                    return false;
                }

                order.Status = RentalOrderStatus.Cancelled;
                order.HoldUntil = null;
                RentalOrderHistory.Record(
                    dbContext, order.Id, RentalOrderEventKind.AdvanceLapsed, order.Quantity, Guid.Empty, toStatus: RentalOrderStatus.Cancelled);
                await dbContext.SaveChangesAsync(cancellationToken);
                return true;
            }, cancellationToken);

            if (done)
            {
                count++;
            }

            dbContext.ChangeTrackerClear();
        }

        return count;
    }

    /// <summary>
    /// An order awaiting its advance is booked once the advance is in — after checking the pieces are
    /// still free if its hold ran out meanwhile. If they are not, it is cancelled and the money shows
    /// as a refund due.
    /// </summary>
    private async Task BookIfAdvancePaidAsync(RentalOrder order, decimal paidNow, Guid actorUserId, CancellationToken cancellationToken)
    {
        if (order.Status != RentalOrderStatus.AwaitingAdvance || paidNow < order.AdvanceDue)
        {
            return;
        }

        var holdLasts = order.HoldUntil is { } until && until > clock.GetUtcNow();
        if (!holdLasts)
        {
            // Its own pieces no longer count as held, so this asks whether they are still free.
            var availability = await dbContext.AvailabilityAsync(order.RentalItem, order.StartDate, order.EndDate, order.Id, cancellationToken);
            if (availability.Available < order.Quantity)
            {
                order.Status = RentalOrderStatus.Cancelled;
                order.HoldUntil = null;
                RentalOrderHistory.Record(
                    dbContext, order.Id, RentalOrderEventKind.AdvanceLapsed, order.Quantity, actorUserId, toStatus: RentalOrderStatus.Cancelled);
                return;
            }
        }

        order.Status = RentalOrderStatus.Booked;
        order.HoldUntil = null;
        RentalOrderHistory.Record(
            dbContext, order.Id, RentalOrderEventKind.StatusChanged, order.Quantity, actorUserId, toStatus: RentalOrderStatus.Booked);
    }
}

internal static class RentDbContextTracking
{
    /// <summary>Forgets tracked rows between independent pieces of work in one long-running scope.</summary>
    public static void ChangeTrackerClear(this IRentDbContext dbContext)
    {
        if (dbContext is DbContext context)
        {
            context.ChangeTracker.Clear();
        }
    }
}

public class RentalPaymentSettingsHandler(
    ICurrentUser currentUser,
    IRentDbContext dbContext,
    IServiceDirectory directory,
    TimeProvider clock) :
    IRequestHandler<GetRentalPaymentSettingsQuery, RentalPaymentSettingsDto>,
    IRequestHandler<UpdateRentalPaymentSettingsCommand, RentalPaymentSettingsDto>
{
    public async Task<RentalPaymentSettingsDto> Handle(GetRentalPaymentSettingsQuery request, CancellationToken cancellationToken)
    {
        var row = await RentalBusinessRefresh.RefreshAsync(
            dbContext, directory, currentUser.OwnerId(), clock.GetUtcNow(), cancellationToken);
        return new RentalPaymentSettingsDto { UpiId = row?.UpiId };
    }

    public async Task<RentalPaymentSettingsDto> Handle(UpdateRentalPaymentSettingsCommand request, CancellationToken cancellationToken)
    {
        var ownerId = currentUser.OwnerId();
        var row = await dbContext.RentalBusinesses.FirstOrDefaultAsync(b => b.OwnerUserId == ownerId, cancellationToken);
        if (row is null)
        {
            // Not refreshed from Service yet: the name arrives with the next refresh.
            row = new RentalBusiness { OwnerUserId = ownerId, RefreshedAt = clock.GetUtcNow() };
            dbContext.RentalBusinesses.Add(row);
        }

        row.UpiId = string.IsNullOrWhiteSpace(request.UpiId) ? null : request.UpiId.Trim().ToLowerInvariant();
        await dbContext.SaveChangesAsync(cancellationToken);
        return new RentalPaymentSettingsDto { UpiId = row.UpiId };
    }
}
