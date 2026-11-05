using MediatR;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Options;
using Zuno.Rent.Application.Common;
using Zuno.Rent.Application.Orders;
using Zuno.Rent.Domain.Entities;
using Zuno.Rent.Domain.Exceptions;

namespace Zuno.Rent.Application.Items;

/// <summary>An item's orders — who has how many, from when to when, and where they went. Newest first.</summary>
public class GetRentalItemOrdersQuery : IRequest<RentalOrderPageDto>
{
    /// <summary>From the route.</summary>
    public Guid RentalItemId { get; set; }

    public int Page { get; set; } = 1;

    public int? PageSize { get; set; }
}

public class RentalOrderDto
{
    public Guid Id { get; set; }

    public Guid RentalItemId { get; set; }

    public string ItemName { get; set; } = string.Empty;

    /// <summary>The business renting it out, as customers see it.</summary>
    public string? BusinessName { get; set; }

    public string CustomerName { get; set; } = string.Empty;

    public string? CustomerPhone { get; set; }

    public int Quantity { get; set; }

    public DateTimeOffset StartDate { get; set; }

    public DateTimeOffset EndDate { get; set; }

    public string DeliveryAddress { get; set; } = string.Empty;

    public string? DistrictName { get; set; }

    /// <summary><c>Booked</c>, <c>OnRent</c>, <c>Returned</c> or <c>Cancelled</c>.</summary>
    public string Status { get; set; } = string.Empty;

    /// <summary>From the status table, e.g. "On rent".</summary>
    public string StatusName { get; set; } = string.Empty;

    /// <summary>From the status table: the colour the app gives it.</summary>
    public string StatusTone { get; set; } = string.Empty;

    /// <summary>Whether these pieces count as out of stock now.</summary>
    public bool IsOut { get; set; }

    /// <summary><c>App</c> (the customer booked it) or <c>Offline</c> (the business took it).</summary>
    public string Source { get; set; } = string.Empty;

    /// <summary>Messages from the other side not opened yet.</summary>
    public int UnreadMessages { get; set; }

    /// <summary>The customer's answers to the item's questions, as asked.</summary>
    public List<RentalOrderAnswerDto> Answers { get; set; } = [];

    /// <summary>The steps the business may take next, from the transition table — the order's buttons.</summary>
    public List<RentalOrderActionDto> Actions { get; set; } = [];

    /// <summary>The order this one adds pieces to, if it is an add-on.</summary>
    public Guid? ParentOrderId { get; set; }

    /// <summary>Extra pieces added to this order later, each its own order — "300 + 200 extra".</summary>
    public List<RentalOrderAddOnDto> AddOns { get; set; } = [];

    /// <summary>Whether pieces can still be added: the order is booked or out.</summary>
    public bool CanAddPieces { get; set; }

    /// <summary><c>Daily</c>, <c>Hourly</c> or <c>Fixed</c> — the rate the order was booked at.</summary>
    public string PriceType { get; set; } = string.Empty;

    public decimal UnitPrice { get; set; }

    /// <summary>Days or hours charged.</summary>
    public int Units { get; set; }

    /// <summary>What the order costs: rate × pieces × days or hours.</summary>
    public decimal Amount { get; set; }

    /// <summary>The advance this order asks; 0 when none.</summary>
    public decimal AdvanceDue { get; set; }

    /// <summary>Paid so far, refunds taken off.</summary>
    public decimal Paid { get; set; }

    /// <summary>Still to be paid.</summary>
    public decimal Balance { get; set; }

    /// <summary>From the payment-status table, e.g. <c>AdvancePaid</c>; null when there is nothing to say.</summary>
    public string? PaymentStatus { get; set; }

    public string? PaymentStatusName { get; set; }

    public string? PaymentStatusTone { get; set; }

    /// <summary>Every payment and refund, oldest first.</summary>
    public List<RentalOrderPaymentDto> Payments { get; set; } = [];

    /// <summary>Until when an order awaiting its advance holds the pieces.</summary>
    public DateTimeOffset? HoldUntil { get; set; }

    /// <summary>What the customer pays now online: the advance while it is awaited, otherwise the balance.</summary>
    public decimal PayNowAmount { get; set; }

    /// <summary>The business may take money in (cash or UPI QR).</summary>
    public bool CanCollect { get; set; }

    /// <summary>The business may record giving money back — a cancelled order still holding some.</summary>
    public bool CanRefund { get; set; }

    /// <summary>The customer may pay online now.</summary>
    public bool CanPayOnline { get; set; }

    /// <summary>The business's UPI ID for the payment QR — shown to the business only; null until it is set.</summary>
    public string? UpiId { get; set; }

    /// <summary>The cancellation charge by time left, as booked — a later change to the item never touches it.</summary>
    public List<RentalCancelStepDto> CancelSteps { get; set; } = [];

    /// <summary><c>Day</c>, or <c>Hour</c> for an hourly order: what the steps count.</summary>
    public string CancelUnit { get; set; } = string.Empty;

    /// <summary><c>ByTimeLeft</c> (the steps) or <c>PerRentalDay</c>, as booked.</summary>
    public string CancelChargeType { get; set; } = string.Empty;

    /// <summary>For <c>PerRentalDay</c>: the percent for each day (or hour) rented.</summary>
    public decimal? CancelPercentPerDay { get; set; }

    /// <summary>The most a per-day charge adds up to, as booked.</summary>
    public decimal CancelPercentCap { get; set; }

    /// <summary><c>Business</c> or <c>Customer</c> on an order one of them cancelled; null otherwise.</summary>
    public string? CancelledBy { get; set; }

    /// <summary>What the business keeps because the customer cancelled; 0 when the business cancelled.</summary>
    public decimal CancellationCharge { get; set; }

    /// <summary>Still to go back to the customer on a cancelled order.</summary>
    public decimal RefundOwed { get; set; }

    /// <summary><c>Online</c> or <c>InHand</c> once the business has chosen; null before.</summary>
    public string? RefundMode { get; set; }

    public string? RefundModeName { get; set; }

    /// <summary>What this side is told about the refund, e.g. "in 1 to 5 working days" — from the refund-mode table.</summary>
    public string? RefundModeText { get; set; }

    /// <summary>
    /// The business still has money to give back here: owed, and not going back online by Zuno.
    /// Such an order sits in the business's to-do list until it is settled.
    /// </summary>
    public bool NeedsRefund { get; set; }

    /// <summary>The business may still choose or change how the refund goes back (none given yet).</summary>
    public bool CanChooseRefundMode { get; set; }

    /// <summary>The refund methods to choose from, when <see cref="CanChooseRefundMode"/>.</summary>
    public List<RentalRefundModeChoiceDto> RefundModes { get; set; } = [];

    /// <summary>The customer may rate it now: returned, fully paid, a main order, and not rated yet.</summary>
    public bool CanRate { get; set; }

    /// <summary>The customer's own stars on it, shown to the customer; null until rated.</summary>
    public short? MyRating { get; set; }

    public string? MyRatingComment { get; set; }

    /// <summary>The stars the customer gave, shown to both sides; null until rated.</summary>
    public short? CustomerRating { get; set; }

    public string? CustomerRatingComment { get; set; }
}

/// <summary>One way to give a refund back, as the business chooses it.</summary>
public class RentalRefundModeChoiceDto
{
    /// <summary><c>Online</c> or <c>InHand</c>.</summary>
    public string Code { get; set; } = string.Empty;

    public string Name { get; set; } = string.Empty;

    public string Text { get; set; } = string.Empty;

    /// <summary>Why it cannot be chosen, e.g. the customer paid in cash; null when it can.</summary>
    public string? DisabledReason { get; set; }
}

/// <summary>One payment line on an order.</summary>
public class RentalOrderPaymentDto
{
    public Guid Id { get; set; }

    public DateTimeOffset At { get; set; }

    /// <summary><c>Advance</c>, <c>Balance</c> or <c>Refund</c>.</summary>
    public string Kind { get; set; } = string.Empty;

    /// <summary>From the method table, e.g. "UPI QR".</summary>
    public string MethodName { get; set; } = string.Empty;

    public decimal Amount { get; set; }

    /// <summary>The UPI transaction reference, when one was recorded.</summary>
    public string? Reference { get; set; }
}

public class RentalOrderAnswerDto
{
    public string Prompt { get; set; } = string.Empty;

    public string Answer { get; set; } = string.Empty;
}

/// <summary>One add-on on an order, as its parent lists it.</summary>
public class RentalOrderAddOnDto
{
    public Guid Id { get; set; }

    public int Quantity { get; set; }

    public string StatusName { get; set; } = string.Empty;

    public string StatusTone { get; set; } = string.Empty;
}

/// <summary>One button on an order: the status it moves to and the words on it.</summary>
public class RentalOrderActionDto
{
    public string ToStatus { get; set; } = string.Empty;

    public string Label { get; set; } = string.Empty;

    /// <summary>Ask "are you sure?" first.</summary>
    public bool ConfirmFirst { get; set; }

    /// <summary>Why the step cannot be taken yet, e.g. "Collect ₹1,500 first"; null when it can.</summary>
    public string? DisabledReason { get; set; }
}

public class RentalOrderPageDto
{
    public List<RentalOrderDto> Items { get; set; } = [];

    public int Page { get; set; }

    public int PageSize { get; set; }

    public int TotalCount { get; set; }
}

public class GetRentalItemOrdersQueryHandler(
    ICurrentUser currentUser,
    IRentDbContext dbContext,
    IOptions<RentSettings> settings) : IRequestHandler<GetRentalItemOrdersQuery, RentalOrderPageDto>
{
    public async Task<RentalOrderPageDto> Handle(GetRentalItemOrdersQuery request, CancellationToken cancellationToken)
    {
        var ownerId = currentUser.OwnerId();

        // The item's owner only — checked before a single order is read.
        var itemOwner = await dbContext.RentalItems
            .Where(i => i.Id == request.RentalItemId)
            .Select(i => (Guid?)i.OwnerUserId)
            .FirstOrDefaultAsync(cancellationToken)
            ?? throw new EntityNotFoundException(nameof(RentalItem), request.RentalItemId);
        if (itemOwner != ownerId)
        {
            throw new ForbiddenException("This rent item does not belong to your business.");
        }

        var limits = settings.Value;
        return await RentalOrderReader.ReadPageAsync(
            dbContext,
            dbContext.RentalOrders.Where(o => o.RentalItemId == request.RentalItemId),
            Math.Max(1, request.Page),
            Math.Clamp(request.PageSize ?? limits.DefaultPageSize, 1, limits.MaxPageSize),
            cancellationToken);
    }
}
