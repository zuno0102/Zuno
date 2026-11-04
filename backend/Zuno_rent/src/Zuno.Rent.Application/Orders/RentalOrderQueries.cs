using MediatR;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Options;
using Zuno.Rent.Application.Common;
using Zuno.Rent.Application.Items;
using Zuno.Rent.Domain.Enums;

namespace Zuno.Rent.Application.Orders;

/// <summary>The business's rent orders across every item, newest first; narrowed to one status if given.</summary>
public class GetMyRentalOrdersQuery : IRequest<RentalOrderPageDto>
{
    /// <summary>
    /// <c>Booked</c>, <c>OnRent</c>, <c>Returned</c>, <c>Cancelled</c>, or null for all — or <c>RefundDue</c>:
    /// cancelled orders that still owe the customer money back.
    /// </summary>
    public string? Status { get; set; }

    public int Page { get; set; } = 1;

    public int? PageSize { get; set; }
}

/// <summary>One rent order of the business's, with its next steps.</summary>
public class GetRentalOrderQuery : IRequest<RentalOrderDto>
{
    public Guid Id { get; set; }
}

/// <summary>How many of the business's rent orders sit in each status — the filter chips.</summary>
public class GetRentalOrderCountsQuery : IRequest<List<RentalOrderStatusCountDto>>;

public class RentalOrderStatusCountDto
{
    public string Status { get; set; } = string.Empty;

    public string Name { get; set; } = string.Empty;

    public string Tone { get; set; } = string.Empty;

    public int Count { get; set; }

    /// <summary>False for a filter that cuts across statuses, like <c>RefundDue</c>: not added into "All".</summary>
    public bool CountsInAll { get; set; } = true;
}

public class RentalOrderQueryHandlers(
    ICurrentUser currentUser,
    IRentDbContext dbContext,
    IOptions<RentSettings> settings) :
    IRequestHandler<GetMyRentalOrdersQuery, RentalOrderPageDto>,
    IRequestHandler<GetRentalOrderQuery, RentalOrderDto>,
    IRequestHandler<GetRentalOrderCountsQuery, List<RentalOrderStatusCountDto>>
{
    /// <summary>The filter for cancelled orders still owing money back, named after the payment status.</summary>
    public static readonly string RefundDueFilter = RentalPaymentStatus.RefundDue.ToString();

    /// <summary>
    /// Cancelled orders where what was paid, less refunds and the cancellation charge kept, is still
    /// above zero — the same sum as <see cref="RentalMoney.RefundOwed"/>, in the database.
    /// </summary>
    private IQueryable<Domain.Entities.RentalOrder> OwingRefund(IQueryable<Domain.Entities.RentalOrder> orders) =>
        orders.Where(o => o.Status == RentalOrderStatus.Cancelled
            && dbContext.RentalOrderPayments
                .Where(p => p.RentalOrderId == o.Id)
                .Sum(p => p.Kind == RentalPaymentKind.Refund ? -p.Amount : p.Amount) > o.CancellationCharge);

    public async Task<RentalOrderPageDto> Handle(GetMyRentalOrdersQuery request, CancellationToken cancellationToken)
    {
        var ownerId = currentUser.OwnerId();
        var limits = settings.Value;

        // Served by the (owner_user_id, start_date) index.
        var orders = dbContext.RentalOrders.Where(o => o.OwnerUserId == ownerId);
        if (string.Equals(request.Status, RefundDueFilter, StringComparison.OrdinalIgnoreCase))
        {
            orders = OwingRefund(orders);
        }
        else if (!string.IsNullOrWhiteSpace(request.Status))
        {
            // An unknown status name matches nothing rather than failing the screen.
            if (!Enum.TryParse<RentalOrderStatus>(request.Status, ignoreCase: true, out var status)
                || int.TryParse(request.Status, out _))
            {
                return new RentalOrderPageDto { Page = 1, PageSize = limits.DefaultPageSize };
            }

            orders = orders.Where(o => o.Status == status);
        }

        return await RentalOrderReader.ReadPageAsync(
            dbContext,
            orders,
            Math.Max(1, request.Page),
            Math.Clamp(request.PageSize ?? limits.DefaultPageSize, 1, limits.MaxPageSize),
            cancellationToken);
    }

    public Task<RentalOrderDto> Handle(GetRentalOrderQuery request, CancellationToken cancellationToken) =>
        RentalOrderReader.ReadOneAsync(dbContext, request.Id, currentUser.OwnerId(), cancellationToken);

    public async Task<List<RentalOrderStatusCountDto>> Handle(GetRentalOrderCountsQuery request, CancellationToken cancellationToken)
    {
        var ownerId = currentUser.OwnerId();

        var counts = await dbContext.RentalOrders
            .Where(o => o.OwnerUserId == ownerId)
            .GroupBy(o => o.Status)
            .Select(g => new { g.Key, Count = g.Count() })
            .ToDictionaryAsync(g => g.Key, g => g.Count, cancellationToken);

        // Every status in the table, in its order, even the empty ones — the chips stay in place.
        var statuses = await dbContext.RentalOrderStatuses.AsNoTracking().OrderBy(s => s.DisplayOrder).ToListAsync(cancellationToken);
        var result = statuses
            .Select(s => new RentalOrderStatusCountDto
            {
                Status = s.Code.ToString(),
                Name = s.Name,
                Tone = s.Tone,
                Count = counts.GetValueOrDefault(s.Code),
            })
            .ToList();

        // First, so money owed back is one tap away; named and coloured by the payment-status table.
        // It is a cut across statuses, so it is not added into "All".
        var refundDue = await dbContext.RentalPaymentStatuses.AsNoTracking()
            .FirstOrDefaultAsync(s => s.Code == RentalPaymentStatus.RefundDue, cancellationToken);
        result.Insert(0, new RentalOrderStatusCountDto
        {
            Status = RefundDueFilter,
            Name = refundDue?.Name ?? RefundDueFilter,
            Tone = refundDue?.Tone ?? "danger",
            Count = await OwingRefund(dbContext.RentalOrders.Where(o => o.OwnerUserId == ownerId)).CountAsync(cancellationToken),
            CountsInAll = false,
        });

        return result;
    }
}
