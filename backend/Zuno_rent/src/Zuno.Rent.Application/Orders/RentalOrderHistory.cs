using MediatR;
using Microsoft.EntityFrameworkCore;
using Zuno.Rent.Application.Common;
using Zuno.Rent.Domain.Entities;
using Zuno.Rent.Domain.Enums;

namespace Zuno.Rent.Application.Orders;

/// <summary>An order's history, oldest first — with its add-ons' steps woven in.</summary>
public class GetRentalOrderHistoryQuery : IRequest<List<RentalOrderEventDto>>
{
    public Guid RentalOrderId { get; set; }
}

/// <summary>One step, as the order page lists it: "30 Oct 08:30 · On rent · 300".</summary>
public class RentalOrderEventDto
{
    public Guid Id { get; set; }

    public DateTimeOffset At { get; set; }

    /// <summary>"Booked", "Extra pieces added", or the status moved to ("On rent").</summary>
    public string Title { get; set; } = string.Empty;

    /// <summary>The app's colour for the step.</summary>
    public string Tone { get; set; } = string.Empty;

    public int Quantity { get; set; }

    /// <summary>Whether the step belongs to an add-on of this order rather than the order itself.</summary>
    public bool OnAddOn { get; set; }

    /// <summary>The add-on order a step is about, where there is one.</summary>
    public Guid? RelatedOrderId { get; set; }

    /// <summary>For a payment step: how much, and how — "₹500 · Cash".</summary>
    public decimal? Amount { get; set; }

    public string? PaymentMethodName { get; set; }
}

/// <summary>Writes history steps. Called beside every change to an order, in the same save.</summary>
internal static class RentalOrderHistory
{
    public static void Record(
        IRentDbContext dbContext,
        Guid orderId,
        RentalOrderEventKind kind,
        int quantity,
        Guid actorUserId,
        RentalOrderStatus? toStatus = null,
        Guid? relatedOrderId = null,
        decimal? amount = null,
        RentalPaymentMethod? method = null) =>
        dbContext.RentalOrderEvents.Add(new RentalOrderEvent
        {
            RentalOrderId = orderId,
            Kind = kind,
            Quantity = quantity,
            ActorUserId = actorUserId,
            ToStatus = toStatus,
            RelatedOrderId = relatedOrderId,
            Amount = amount,
            PaymentMethod = method,
        });
}

/// <summary>The customer's view of the same history — the steps of an order they booked.</summary>
public class GetMyRentalOrderHistoryQuery : IRequest<List<RentalOrderEventDto>>
{
    public Guid RentalOrderId { get; set; }
}

public class GetRentalOrderHistoryQueryHandler(ICurrentUser currentUser, IRentDbContext dbContext) :
    IRequestHandler<GetRentalOrderHistoryQuery, List<RentalOrderEventDto>>,
    IRequestHandler<GetMyRentalOrderHistoryQuery, List<RentalOrderEventDto>>
{
    public Task<List<RentalOrderEventDto>> Handle(GetRentalOrderHistoryQuery request, CancellationToken cancellationToken) =>
        ReadAsync(request.RentalOrderId, RentalAudience.Business, cancellationToken);

    public Task<List<RentalOrderEventDto>> Handle(GetMyRentalOrderHistoryQuery request, CancellationToken cancellationToken) =>
        ReadAsync(request.RentalOrderId, RentalAudience.Customer, cancellationToken);

    private async Task<List<RentalOrderEventDto>> ReadAsync(Guid orderId, RentalAudience audience, CancellationToken cancellationToken)
    {
        await dbContext.EnsureOrderAccessAsync(orderId, currentUser.OwnerId(), audience, cancellationToken);
        var request = new { RentalOrderId = orderId };

        var addOnIds = dbContext.RentalOrders
            .Where(o => o.ParentOrderId == request.RentalOrderId)
            .Select(o => o.Id);

        var events = await dbContext.RentalOrderEvents
            .AsNoTracking()
            .Where(e => e.RentalOrderId == request.RentalOrderId || addOnIds.Contains(e.RentalOrderId))
            .OrderBy(e => e.CreatedDate)
            // Steps written in one save share a time: the add-on's booking reads before the note on
            // the first order that it was added, and a payment before the status it brought about.
            .ThenBy(e => e.Kind == RentalOrderEventKind.StatusChanged)
            .ThenBy(e => e.Kind)
            .ToListAsync(cancellationToken);

        var kinds = await dbContext.RentalOrderEventKinds.AsNoTracking().ToDictionaryAsync(k => k.Code, cancellationToken);
        var statuses = await dbContext.RentalOrderStatuses.AsNoTracking().ToDictionaryAsync(s => s.Code, cancellationToken);
        var methods = await dbContext.RentalPaymentMethods.AsNoTracking().ToDictionaryAsync(m => m.Code, m => m.Name, cancellationToken);

        return events.Select(e =>
        {
            var status = e.ToStatus is { } to ? statuses.GetValueOrDefault(to) : null;
            return new RentalOrderEventDto
            {
                Id = e.Id,
                At = e.CreatedDate,
                Title = e.Kind == RentalOrderEventKind.StatusChanged && status is not null
                    ? status.Name
                    : kinds.GetValueOrDefault(e.Kind)?.Name ?? e.Kind.ToString(),
                Tone = status?.Tone
                    ?? (e.Kind is RentalOrderEventKind.AdvancePaid or RentalOrderEventKind.PaymentReceived or RentalOrderEventKind.Refunded
                        ? "success"
                        : e.Kind == RentalOrderEventKind.AdvanceLapsed ? "danger" : "progress"),
                Quantity = e.Quantity,
                OnAddOn = e.RentalOrderId != request.RentalOrderId,
                RelatedOrderId = e.RelatedOrderId,
                Amount = e.Amount,
                PaymentMethodName = e.PaymentMethod is { } m ? methods.GetValueOrDefault(m) ?? m.ToString() : null,
            };
        }).ToList();
    }
}
