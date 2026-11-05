using FluentValidation;
using MediatR;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Options;
using Zuno.Rent.Application.Common;
using Zuno.Rent.Application.Items;
using Zuno.Rent.Domain.Entities;
using Zuno.Rent.Domain.Enums;
using Zuno.Rent.Domain.Exceptions;

namespace Zuno.Rent.Application.Orders;

/// <summary>
/// The business books some of an item for a customer who phoned or came in — refused when the dates
/// do not leave enough: "Only 300 Plastic chair available for 1 Nov – 3 Nov".
/// </summary>
public class CreateRentalOrderCommand : IRequest<RentalOrderDto>
{
    public Guid RentalItemId { get; set; }

    public int Quantity { get; set; }

    public DateTimeOffset StartDate { get; set; }

    public DateTimeOffset EndDate { get; set; }

    public string CustomerName { get; set; } = string.Empty;

    /// <summary>The customer's Indian mobile; required — the business calls it about delivery and return.</summary>
    public string? CustomerPhone { get; set; }

    public string DeliveryAddress { get; set; } = string.Empty;

    public Guid? DistrictId { get; set; }

    /// <summary>
    /// How the customer paid the advance — <c>Cash</c> or <c>UpiQr</c>. Required whenever an advance
    /// is taken; ignored when none is.
    /// </summary>
    public string? AdvanceMethod { get; set; }

    /// <summary>
    /// The advance taken now, as the business typed it. Null takes the item's own advance; it can be
    /// more (up to the order's total) but never less than the item asks. 0 takes none.
    /// </summary>
    public decimal? AdvanceAmount { get; set; }

    /// <summary>
    /// The business says the advance is already in its hands — counted in cash, or seen in its UPI
    /// app. Only then is it recorded. Either way the order is booked (confirmed); an advance not yet
    /// received stays due and is collected from the order later. Left out (an app from before this
    /// choice existed), saying how the advance was paid means it was received.
    /// </summary>
    public bool? AdvanceReceived { get; set; }

    /// <summary>Whether the advance is in the business's hands — said outright, or implied by a method.</summary>
    public bool AdvanceInHand => AdvanceReceived ?? !string.IsNullOrWhiteSpace(AdvanceMethod);
}

/// <summary>
/// More pieces for an order already running — the customer who got 300 chairs and now needs 200
/// more. A new order of its own, linked to the first, with its own delivery and return.
/// </summary>
public class AddRentalOrderAddOnCommand : IRequest<RentalOrderDto>
{
    /// <summary>The order being added to; from the route.</summary>
    public Guid ParentOrderId { get; set; }

    public int Quantity { get; set; }

    /// <summary>Null keeps the first order's end; a later date keeps the extra pieces longer.</summary>
    public DateTimeOffset? EndDate { get; set; }
}

/// <summary>How many of an item a new order for some dates can still take.</summary>
public class GetRentalAvailabilityQuery : IRequest<RentalAvailabilityDto>
{
    public Guid RentalItemId { get; set; }

    public DateTimeOffset StartDate { get; set; }

    public DateTimeOffset EndDate { get; set; }
}

public class CreateRentalOrderCommandValidator : AbstractValidator<CreateRentalOrderCommand>
{
    public CreateRentalOrderCommandValidator(IRentDbContext dbContext, IOptions<RentSettings> settings, TimeProvider clock)
    {
        var limits = settings.Value;

        RuleFor(x => x.RentalItemId).NotEmpty();
        RuleFor(x => x.Quantity)
            .GreaterThanOrEqualTo(1).WithMessage("Book at least one.")
            .LessThanOrEqualTo(limits.MaxQuantityOwned);
        RentalOrderDates.Rules(this, x => x.StartDate, x => x.EndDate, clock);
        RuleFor(x => x.CustomerName)
            .Must(name => !string.IsNullOrWhiteSpace(name)).WithMessage("Give the customer's name.")
            .MaximumLength(200);
        RuleFor(x => x.CustomerPhone)
            .Cascade(CascadeMode.Stop)
            .Must(phone => !string.IsNullOrWhiteSpace(phone)).WithMessage(RentalPhone.Missing)
            .Must(phone => RentalPhone.Normalize(phone) is not null).WithMessage(RentalPhone.Hint);
        RuleFor(x => x.DeliveryAddress)
            .Must(address => !string.IsNullOrWhiteSpace(address)).WithMessage("Say where the pieces go.")
            .MaximumLength(500);
        RuleFor(x => x.DistrictId)
            .MustAsync((id, cancellationToken) => dbContext.Districts.AnyAsync(d => d.Id == id, cancellationToken))
            .When(x => x.DistrictId.HasValue)
            .WithMessage("Choose a district from the list.");
        RuleFor(x => x.AdvanceMethod)
            .Must(value => RentalPayments.ParseMethod(value).HasValue)
            .When(x => !string.IsNullOrWhiteSpace(x.AdvanceMethod))
            .WithMessage("Say how the advance was paid: cash or UPI QR.");
        RuleFor(x => x.AdvanceAmount)
            .GreaterThanOrEqualTo(0).WithMessage("The advance cannot be below zero.")
            .PrecisionScale(14, 2, true).WithMessage("Enter the advance in rupees and paise, e.g. 500 or 499.50.")
            .When(x => x.AdvanceAmount.HasValue);
    }
}

public class AddRentalOrderAddOnCommandValidator : AbstractValidator<AddRentalOrderAddOnCommand>
{
    public AddRentalOrderAddOnCommandValidator(IOptions<RentSettings> settings)
    {
        RuleFor(x => x.ParentOrderId).NotEmpty();
        RuleFor(x => x.Quantity)
            .GreaterThanOrEqualTo(1).WithMessage("Add at least one.")
            .LessThanOrEqualTo(settings.Value.MaxQuantityOwned);
    }
}

public class GetRentalAvailabilityQueryValidator : AbstractValidator<GetRentalAvailabilityQuery>
{
    public GetRentalAvailabilityQueryValidator()
    {
        RuleFor(x => x.RentalItemId).NotEmpty();
        RuleFor(x => x.EndDate).GreaterThan(x => x.StartDate).WithMessage("The end must be after the start.");
    }
}

/// <summary>The date rules every order shares: ends after it starts, not in the past, within a year.</summary>
internal static class RentalOrderDates
{
    public const int MaxDays = 366;

    public static void Rules<T>(
        AbstractValidator<T> validator,
        System.Linq.Expressions.Expression<Func<T, DateTimeOffset>> start,
        System.Linq.Expressions.Expression<Func<T, DateTimeOffset>> end,
        TimeProvider clock)
    {
        var startOf = start.Compile();

        // A day of slack: the app sends the start of the business's day, which can be hours behind UTC.
        validator.RuleFor(start)
            .Must(value => value >= clock.GetUtcNow().AddDays(-1))
            .WithMessage("The rental cannot start in the past.");
        validator.RuleFor(end)
            .Must((x, value) => value > startOf(x))
            .WithMessage("The end must be after the start.")
            .Must((x, value) => (value - startOf(x)).TotalDays <= MaxDays)
            .WithMessage($"A rental can run at most {MaxDays} days.");
    }
}

public class RentalOrderCreateHandlers(ICurrentUser currentUser, IRentDbContext dbContext, TimeProvider clock) :
    IRequestHandler<CreateRentalOrderCommand, RentalOrderDto>,
    IRequestHandler<AddRentalOrderAddOnCommand, RentalOrderDto>,
    IRequestHandler<GetRentalAvailabilityQuery, RentalAvailabilityDto>
{
    public async Task<RentalOrderDto> Handle(CreateRentalOrderCommand request, CancellationToken cancellationToken)
    {
        var ownerId = currentUser.OwnerId();
        var item = await OwnedItemAsync(request.RentalItemId, ownerId, cancellationToken);
        var advanceMethod = RentalPayments.ParseMethod(request.AdvanceMethod);

        var orderId = await dbContext.WithItemLockAsync(item.Id, async () =>
        {
            // Inside the lock, so a booking made a moment ago is already counted.
            await dbContext.EnsureAvailableAsync(item, request.Quantity, request.StartDate, request.EndDate, cancellationToken);

            var order = new RentalOrder
            {
                RentalItemId = item.Id,
                OwnerUserId = ownerId,
                CustomerName = request.CustomerName.Trim(),
                CustomerPhone = RentalPhone.Normalize(request.CustomerPhone),
                Quantity = request.Quantity,

                // Stored in UTC: the app sends the business's own offset, which the database refuses.
                StartDate = request.StartDate.ToUniversalTime(),
                EndDate = request.EndDate.ToUniversalTime(),
                DeliveryAddress = request.DeliveryAddress.Trim(),
                DistrictId = request.DistrictId,
                Status = RentalOrderStatus.Booked,
            };
            order.PriceFrom(item.PriceType, item.Price);
            order.AdvanceDue = OfflineAdvance(item, order, request.AdvanceAmount);
            dbContext.RentalOrders.Add(order);
            RentalOrderHistory.Record(dbContext, order.Id, RentalOrderEventKind.Booked, order.Quantity, ownerId);

            // An offline order is the business's own word with its customer, so it is confirmed at
            // once. An advance not in hand yet is simply not recorded: it stays due, and the business
            // collects it from the order later, as it would any balance.
            // An advance the business has in hand: it says how it came.
            if (order.AdvanceDue > 0 && request.AdvanceInHand)
            {
                if (advanceMethod is not { } method || !await RentalPayments.BusinessMayRecordAsync(dbContext, method, cancellationToken))
                {
                    throw new DomainException(item.AdvanceType != RentalAdvanceType.None
                        ? $"{item.Name} asks an advance of {RentalMoney.Text(order.AdvanceDue)}. Say how it was paid: cash or UPI QR."
                        : $"Say how the advance of {RentalMoney.Text(order.AdvanceDue)} was paid: cash or UPI QR.");
                }

                RentalMoney.Record(
                    dbContext, order, RentalPaymentKind.Advance, method, order.AdvanceDue, ownerId, RentalMessageSenderRole.Business);
            }

            await dbContext.SaveChangesAsync(cancellationToken);
            return order.Id;
        }, cancellationToken);

        return await RentalOrderReader.ReadOneAsync(dbContext, orderId, ownerId, cancellationToken);
    }

    public async Task<RentalOrderDto> Handle(AddRentalOrderAddOnCommand request, CancellationToken cancellationToken)
    {
        var ownerId = currentUser.OwnerId();
        await dbContext.EnsureOwnedOrderAsync(request.ParentOrderId, ownerId, cancellationToken);

        var parent = await dbContext.RentalOrders.AsNoTracking().FirstAsync(o => o.Id == request.ParentOrderId, cancellationToken);

        // Only an order still running: pieces cannot be added to one that is over.
        var holds = await dbContext.HoldingOrders().AnyAsync(o => o.Id == parent.Id, cancellationToken);
        if (!holds)
        {
            throw new DomainException("This order is finished, so pieces cannot be added to it. Make a new order instead.");
        }

        // From now (or the order's start, if still ahead) to the order's end, or later if asked.
        var now = clock.GetUtcNow();
        var start = parent.StartDate > now ? parent.StartDate : now;
        var end = request.EndDate?.ToUniversalTime() ?? parent.EndDate;
        if (end <= start)
        {
            throw new DomainException("The order has already ended. Choose until when the extra pieces are needed.");
        }

        var item = await dbContext.RentalItems.AsNoTracking().FirstAsync(i => i.Id == parent.RentalItemId, cancellationToken);

        var orderId = await dbContext.WithItemLockAsync(item.Id, async () =>
        {
            await dbContext.EnsureAvailableAsync(item, request.Quantity, start, end, cancellationToken);

            var addOn = new RentalOrder
            {
                RentalItemId = parent.RentalItemId,
                OwnerUserId = ownerId,
                ParentOrderId = parent.Id,
                CustomerUserId = parent.CustomerUserId,
                CustomerName = parent.CustomerName,
                CustomerPhone = parent.CustomerPhone,
                Quantity = request.Quantity,
                StartDate = start,
                EndDate = end,
                DeliveryAddress = parent.DeliveryAddress,
                DistrictId = parent.DistrictId,
                Status = RentalOrderStatus.Booked,
            };

            // At the rate the first order was booked at; no advance of its own — paid before its return.
            addOn.PriceFrom(
                parent.UnitPrice > 0 ? parent.PriceType : item.PriceType,
                parent.UnitPrice > 0 ? parent.UnitPrice : item.Price);
            dbContext.RentalOrders.Add(addOn);

            // Both records say it: the add-on was booked, and the first order got extra pieces.
            RentalOrderHistory.Record(dbContext, addOn.Id, RentalOrderEventKind.Booked, addOn.Quantity, ownerId);
            RentalOrderHistory.Record(
                dbContext, parent.Id, RentalOrderEventKind.AddOnAdded, addOn.Quantity, ownerId, relatedOrderId: addOn.Id);
            await dbContext.SaveChangesAsync(cancellationToken);
            return addOn.Id;
        }, cancellationToken);

        return await RentalOrderReader.ReadOneAsync(dbContext, orderId, ownerId, cancellationToken);
    }

    public async Task<RentalAvailabilityDto> Handle(GetRentalAvailabilityQuery request, CancellationToken cancellationToken)
    {
        var item = await OwnedItemAsync(request.RentalItemId, currentUser.OwnerId(), cancellationToken);
        return await dbContext.AvailabilityAsync(item, request.StartDate, request.EndDate, null, cancellationToken);
    }

    /// <summary>
    /// The advance an offline order takes: the item's own unless the business typed one — never less
    /// than the item asks, never more than the order costs.
    /// </summary>
    private static decimal OfflineAdvance(RentalItem item, RentalOrder order, decimal? typed)
    {
        var required = RentalCharge.Advance(item.AdvanceType, item.AdvanceAmount, order.Quantity, order.Amount);
        if (typed is not { } amount)
        {
            return required;
        }

        if (amount < required)
        {
            throw new DomainException(
                $"{item.Name} asks an advance of at least {RentalMoney.Text(required)}.");
        }

        if (amount > order.Amount)
        {
            throw new DomainException(
                $"The advance cannot be more than the order's total of {RentalMoney.Text(order.Amount)}.");
        }

        return amount;
    }

    private async Task<RentalItem> OwnedItemAsync(Guid itemId, Guid ownerId, CancellationToken cancellationToken)
    {
        var item = await dbContext.RentalItems.AsNoTracking().FirstOrDefaultAsync(i => i.Id == itemId, cancellationToken)
            ?? throw new EntityNotFoundException(nameof(RentalItem), itemId);
        if (item.OwnerUserId != ownerId)
        {
            throw new ForbiddenException("This rent item does not belong to your business.");
        }

        return item;
    }
}
