using Microsoft.EntityFrameworkCore;
using Zuno.Marketplace.Application.Common;
using Zuno.Marketplace.Domain.Entities;
using Zuno.Marketplace.Domain.Enums;
using Zuno.Marketplace.Domain.Exceptions;

namespace Zuno.Marketplace.Application.Orders;

/// <summary>The words, colours, steps and couriers every order read needs, read once per request.</summary>
internal sealed record MarketplaceOrderLookups(
    IReadOnlyList<MarketplaceOrderStatusOption> Statuses,
    IReadOnlyList<MarketplaceOrderTransition> Transitions,
    IReadOnlyList<MarketplaceCourier> Couriers,
    IReadOnlyList<MarketplacePaymentMethodOption> PaymentMethods)
{
    public static async Task<MarketplaceOrderLookups> LoadAsync(MarketplaceReference reference, CancellationToken cancellationToken) =>
        new(
            await reference.OrderStatusesAsync(cancellationToken),
            await reference.OrderTransitionsAsync(cancellationToken),
            await reference.CouriersAsync(cancellationToken),
            await reference.PaymentMethodsAsync(cancellationToken));

    /// <summary>The row for a step from <paramref name="from"/> to <paramref name="to"/> that <paramref name="actor"/> may take.</summary>
    public MarketplaceOrderTransition? Step(MarketplaceOrderStatus from, MarketplaceOrderStatus to, MarketplaceOrderActor actor) =>
        Transitions.FirstOrDefault(t => t.FromStatus == from && t.ToStatus == to && t.AllowedFor(actor));
}

/// <summary>Stock, cancelling and reading of orders — shared by the business, the customer and the timed job.</summary>
internal static class MarketplaceOrderCore
{
    /// <summary>The short number on a card: the id's first eight letters.</summary>
    public static string Number(Guid id) => id.ToString("N")[..8].ToUpperInvariant();

    /// <summary>The order, tracked, with its history — refused unless it is <paramref name="userId"/>'s as <paramref name="actor"/>.</summary>
    public static async Task<MarketplaceOrder> AccessibleOrderAsync(
        this IMarketplaceDbContext dbContext, Guid orderId, Guid userId, MarketplaceOrderActor actor, CancellationToken cancellationToken)
    {
        var order = await dbContext.Orders.Include(o => o.Events)
            .FirstOrDefaultAsync(o => o.Id == orderId, cancellationToken)
            ?? throw new EntityNotFoundException("Order", orderId);

        var mine = actor == MarketplaceOrderActor.Business ? order.OwnerUserId == userId : order.CustomerUserId == userId;
        if (!mine)
        {
            throw new ForbiddenException("This order is not yours.");
        }

        return order;
    }

    /// <summary>Takes <paramref name="quantity"/> off the stock of the product (or its colour / size).</summary>
    public static void Hold(MarketplacePost post, MarketplacePostVariant? variant, int quantity)
    {
        if (variant is null)
        {
            if ((post.Quantity ?? 0) < quantity)
            {
                throw new DomainException(OnlyLeft(post.Quantity ?? 0));
            }

            post.Quantity -= quantity;
            return;
        }

        if (variant.Stock < quantity)
        {
            throw new DomainException(OnlyLeft(variant.Stock));
        }

        variant.Stock -= quantity;
        post.Quantity = post.ActiveVariantStock;
    }

    /// <summary>
    /// Puts a cancelled order's pieces back on its product. A product or colour removed since keeps
    /// nothing to put back into.
    /// </summary>
    public static async Task ReleaseAsync(this IMarketplaceDbContext dbContext, MarketplaceOrder order, CancellationToken cancellationToken)
    {
        var post = await dbContext.Posts.Include(p => p.Variants)
            .FirstOrDefaultAsync(p => p.Id == order.PostId, cancellationToken);
        if (post is null)
        {
            return;
        }

        if (order.VariantId is null)
        {
            post.Quantity = (post.Quantity ?? 0) + order.Quantity;
            return;
        }

        if (post.Variants.FirstOrDefault(v => v.Id == order.VariantId) is { } variant)
        {
            variant.Stock += order.Quantity;
            post.Quantity = post.ActiveVariantStock;
        }
    }

    /// <summary>
    /// Cancels an order: its stock goes back, and money paid online is owed back to the customer. The
    /// refund itself is tried at once by the caller, and again by the timed job until it goes through.
    /// </summary>
    public static async Task CancelAsync(
        this IMarketplaceDbContext dbContext,
        MarketplaceOrder order,
        MarketplaceOrderActor actor,
        Guid? actorUserId,
        DateTimeOffset now,
        CancellationToken cancellationToken,
        string? note = null)
    {
        await dbContext.ReleaseAsync(order, cancellationToken);
        order.CancelledAt = now;
        order.CancelledBy = actor;
        order.RefundDue = order.PaymentMethod == MarketplacePaymentMethod.Online && order.PaidAt is not null && order.RefundId is null;
        dbContext.OrderEvents.Add(order.MoveTo(MarketplaceOrderStatus.Cancelled, actor, actorUserId, now, note));
    }

    /// <summary>Gives back a cancelled order's online payment. False when the gateway did not take it this time.</summary>
    public static async Task<bool> TryRefundAsync(
        this IMarketplacePaymentGateway gateway, MarketplaceOrder order, CancellationToken cancellationToken)
    {
        if (!order.RefundDue || order.RefundId is not null || order.ProviderPaymentId is null)
        {
            return false;
        }

        try
        {
            order.RefundId = await gateway.RefundAsync(order.ProviderPaymentId, order.Amount, cancellationToken);
            order.RefundDue = false;
            return true;
        }
        catch (Exception exception) when (exception is HttpRequestException or InvalidOperationException or TaskCanceledException)
        {
            // Left owed: the timed job asks again.
            return false;
        }
    }

    /// <summary>The cover photo per order: the colour's own first photo, else the product's.</summary>
    public static async Task<Dictionary<Guid, string>> ImagesAsync(
        this IMarketplaceDbContext dbContext, IReadOnlyCollection<MarketplaceOrder> orders, CancellationToken cancellationToken)
    {
        var postIds = orders.Select(o => o.PostId).Distinct().ToList();
        var media = await dbContext.PostMedia.AsNoTracking()
            .Where(m => postIds.Contains(m.PostId) && m.SortOrder == 0)
            .Select(m => new { m.PostId, m.VariantId, m.Url })
            .ToListAsync(cancellationToken);

        var images = new Dictionary<Guid, string>();
        foreach (var order in orders)
        {
            var url = media.FirstOrDefault(m => m.PostId == order.PostId && m.VariantId != null && m.VariantId == order.VariantId)?.Url
                ?? media.FirstOrDefault(m => m.PostId == order.PostId && m.VariantId == null)?.Url;
            if (url is not null)
            {
                images[order.Id] = url;
            }
        }

        return images;
    }

    public static MarketplaceOrderDto ToDto(
        this MarketplaceOrder order, MarketplaceOrderActor viewer, MarketplaceOrderLookups lookups, string? imageUrl, bool withHistory)
    {
        var status = lookups.Statuses.FirstOrDefault(s => s.Code == order.Status);
        var courier = lookups.Couriers.FirstOrDefault(c => c.Code == order.CourierCode);
        var method = lookups.PaymentMethods.FirstOrDefault(m => m.Code == order.PaymentMethod);

        return new MarketplaceOrderDto
        {
            Id = order.Id,
            Number = Number(order.Id),
            PostId = order.PostId,
            Title = order.Title,
            VariantName = order.VariantName,
            ImageUrl = imageUrl,
            Quantity = order.Quantity,
            UnitPrice = order.UnitPrice,
            Amount = order.Amount,
            PaymentMethod = order.PaymentMethod.ToString(),
            PaymentMethodName = method?.Name ?? order.PaymentMethod.ToString(),
            IsPaid = order.PaidAt is not null,
            PaidAt = order.PaidAt,
            DueToBusiness = order.DueToBusiness,
            RefundDue = order.RefundDue,
            Refunded = order.RefundId is not null,
            Status = order.Status.ToString(),
            StatusName = status?.Name ?? order.Status.ToString(),
            StatusTone = status?.Tone ?? "waiting",
            CustomerName = order.CustomerName,
            CustomerPhone = order.CustomerPhone,
            DeliveryAddress = order.DeliveryAddress,
            Pincode = order.Pincode,
            CourierCode = order.CourierCode,
            CourierName = order.CourierName,
            TrackingNumber = order.TrackingNumber,
            TrackingUrl = MarketplaceCourier.TrackingLink(courier?.TrackingUrl, order.TrackingNumber),
            ReceiptUrl = order.ReceiptUrl,
            PayBy = order.PayBy,
            ShippedAt = order.ShippedAt,
            DeliveredAt = order.DeliveredAt,
            ClosesAt = order.ClosesAt,
            ClosedAt = order.ClosedAt,
            CancelledAt = order.CancelledAt,
            CancelledBy = order.CancelledBy?.ToString(),
            RatingScore = order.RatingScore,
            RatingComment = order.RatingComment,
            RatedAt = order.RatedAt,
            CreatedDate = order.CreatedDate,
            Actions = lookups.Transitions
                .Where(t => t.FromStatus == order.Status && t.AllowedFor(viewer))
                .OrderBy(t => t.DisplayOrder)
                .Select(t => new MarketplaceOrderActionDto
                {
                    ToStatus = t.ToStatus.ToString(),
                    Name = t.ActionName,
                    NeedsConfirm = t.NeedsConfirm,
                    NeedsTracking = t.NeedsTracking,
                })
                .ToList(),
            Events = withHistory
                ? order.Events
                    .OrderBy(e => e.At)
                    .Select(e => new MarketplaceOrderEventDto
                    {
                        Status = e.Status.ToString(),
                        StatusName = lookups.Statuses.FirstOrDefault(s => s.Code == e.Status)?.Name ?? e.Status.ToString(),
                        Actor = e.Actor.ToString(),
                        Note = e.Note,
                        At = e.At,
                    })
                    .ToList()
                : [],
        };
    }

    /// <summary>Every status with its count, in display order — zeros too, so the chips never jump.</summary>
    public static List<MarketplaceStatusCountDto> Counts<TStatus>(
        IEnumerable<TStatus> statusesInOrder, IReadOnlyDictionary<TStatus, int> counts)
        where TStatus : struct, Enum =>
        statusesInOrder
            .Select(s => new MarketplaceStatusCountDto { Status = s.ToString(), Count = counts.GetValueOrDefault(s) })
            .ToList();

    private static string OnlyLeft(int left) =>
        left <= 0 ? "This is out of stock now." : $"Only {left} left. Order {left} or fewer.";
}
