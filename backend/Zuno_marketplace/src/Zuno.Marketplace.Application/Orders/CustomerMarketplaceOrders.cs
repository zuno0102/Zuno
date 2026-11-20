using FluentValidation;
using MediatR;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Options;
using Zuno.Marketplace.Application.Common;
using Zuno.Marketplace.Domain.Entities;
using Zuno.Marketplace.Domain.Enums;
using Zuno.Marketplace.Domain.Exceptions;

namespace Zuno.Marketplace.Application.Orders;

/// <summary>A customer orders a product: which colour / size, how many, how they pay, where it goes.</summary>
public class PlaceMarketplaceOrderCommand : IRequest<MarketplaceOrderDto>
{
    public Guid PostId { get; set; }

    /// <summary>Required on a product with colours / sizes.</summary>
    public Guid? VariantId { get; set; }

    public int Quantity { get; set; } = 1;

    /// <summary><c>CashOnDelivery</c> or <c>Online</c>.</summary>
    public string PaymentMethod { get; set; } = string.Empty;

    /// <summary>The mobile the courier calls; the account's own when empty.</summary>
    public string? Phone { get; set; }

    public string DeliveryAddress { get; set; } = string.Empty;

    public string Pincode { get; set; } = string.Empty;
}

/// <summary>Opens a payment for an order waiting to be paid online.</summary>
public class StartMarketplaceOrderPaymentCommand : IRequest<MarketplaceCheckoutDto>
{
    public Guid Id { get; set; }
}

/// <summary>The payment came back from the gateway. Counted only when its signature checks out, and only once.</summary>
public class CompleteMarketplaceOrderPaymentCommand : IRequest<MarketplaceOrderDto>
{
    public Guid Id { get; set; }

    public string ProviderOrderId { get; set; } = string.Empty;

    public string PaymentId { get; set; } = string.Empty;

    public string Signature { get; set; } = string.Empty;
}

/// <summary>The customer cancels — only before the order ships.</summary>
public class CancelMarketplaceOrderCommand : IRequest<MarketplaceOrderDto>
{
    public Guid Id { get; set; }
}

/// <summary>The customer's stars and words on a delivered order. It closes the order.</summary>
public class ReviewMarketplaceOrderCommand : IRequest<MarketplaceOrderDto>
{
    public Guid Id { get; set; }

    public short Score { get; set; }

    public string? Comment { get; set; }
}

public class GetMyMarketplaceOrdersQuery : IRequest<MarketplaceOrderPageDto>
{
    public int Page { get; set; } = 1;

    public int? PageSize { get; set; }

    /// <summary>One status, e.g. <c>Shipped</c>; null for all.</summary>
    public string? Status { get; set; }
}

/// <summary>One of the customer's own orders, with its history and progress bar.</summary>
public class GetMyMarketplaceOrderQuery : IRequest<MarketplaceOrderDto>
{
    public Guid Id { get; set; }
}

public class GetMyMarketplaceOrdersQueryValidator : AbstractValidator<GetMyMarketplaceOrdersQuery>
{
    public GetMyMarketplaceOrdersQueryValidator() =>
        RuleFor(x => x.Status)
            .Must(s => s is null || Enum.TryParse<MarketplaceOrderStatus>(s, true, out var v) && Enum.IsDefined(v))
            .WithMessage("Unknown order status.");
}

public class PlaceMarketplaceOrderCommandValidator : AbstractValidator<PlaceMarketplaceOrderCommand>
{
    public PlaceMarketplaceOrderCommandValidator(IOptions<MarketplaceSettings> settings)
    {
        RuleFor(x => x.PostId).NotEmpty();
        RuleFor(x => x.Quantity).InclusiveBetween(1, settings.Value.MaxQuantity);
        RuleFor(x => x.PaymentMethod)
            .Must(m => MarketplaceOrderParsing.PaymentMethod(m) is not null)
            .WithMessage("Choose cash on delivery or online pay.");
        RuleFor(x => x.Phone)
            .Matches(MarketplaceOrderLimits.MobilePattern)
            .When(x => !string.IsNullOrWhiteSpace(x.Phone))
            .WithMessage("Enter a 10-digit mobile number.");
        RuleFor(x => x.DeliveryAddress)
            .Must(a => !string.IsNullOrWhiteSpace(a)).WithMessage("Enter the delivery address.")
            .MaximumLength(MarketplaceOrderLimits.AddressLength);
        RuleFor(x => x.Pincode).Matches(MarketplaceOrderLimits.PincodePattern).WithMessage("Enter the 6-digit pincode.");
    }
}

public class CompleteMarketplaceOrderPaymentCommandValidator : AbstractValidator<CompleteMarketplaceOrderPaymentCommand>
{
    public CompleteMarketplaceOrderPaymentCommandValidator()
    {
        RuleFor(x => x.Id).NotEmpty();
        RuleFor(x => x.ProviderOrderId).NotEmpty().MaximumLength(100);
        RuleFor(x => x.PaymentId).NotEmpty().MaximumLength(100);
        RuleFor(x => x.Signature).MaximumLength(200);
    }
}

public class ReviewMarketplaceOrderCommandValidator : AbstractValidator<ReviewMarketplaceOrderCommand>
{
    public ReviewMarketplaceOrderCommandValidator()
    {
        RuleFor(x => x.Id).NotEmpty();
        RuleFor(x => x.Score).InclusiveBetween((short)1, (short)5).WithMessage("Give 1 to 5 stars.");
        RuleFor(x => x.Comment).MaximumLength(MarketplaceOrderLimits.ReviewLength);
    }
}

/// <summary>The customer's side of product orders. The customer is always the signed-in user.</summary>
public class CustomerMarketplaceOrderHandlers(
    ICurrentUser currentUser,
    IMarketplaceDbContext dbContext,
    IMarketplacePaymentGateway gateway,
    IServiceDirectory directory,
    MarketplaceReference reference,
    TimeProvider clock,
    IOptions<MarketplaceSettings> settings) :
    IRequestHandler<PlaceMarketplaceOrderCommand, MarketplaceOrderDto>,
    IRequestHandler<StartMarketplaceOrderPaymentCommand, MarketplaceCheckoutDto>,
    IRequestHandler<CompleteMarketplaceOrderPaymentCommand, MarketplaceOrderDto>,
    IRequestHandler<CancelMarketplaceOrderCommand, MarketplaceOrderDto>,
    IRequestHandler<ReviewMarketplaceOrderCommand, MarketplaceOrderDto>,
    IRequestHandler<GetMyMarketplaceOrdersQuery, MarketplaceOrderPageDto>,
    IRequestHandler<GetMyMarketplaceOrderQuery, MarketplaceOrderDto>
{
    private const MarketplaceOrderActor Customer = MarketplaceOrderActor.Customer;

    public async Task<MarketplaceOrderDto> Handle(PlaceMarketplaceOrderCommand request, CancellationToken cancellationToken)
    {
        var customerId = currentUser.OwnerId();
        var now = clock.GetUtcNow();
        var method = MarketplaceOrderParsing.PaymentMethod(request.PaymentMethod)!.Value;

        var post = await dbContext.Posts.AsNoTracking()
            .VisibleToCustomers(dbContext.Businesses, now)
            .Where(MarketplaceQueries.IsProduct)
            .FirstOrDefaultAsync(p => p.Id == request.PostId, cancellationToken)
            ?? throw new DomainException("This product is not on sale just now.");
        if (!post.KeepsStock)
        {
            throw new DomainException("This item is sold by calling the seller, not ordered in the app.");
        }

        if (post.OwnerUserId == customerId)
        {
            throw new DomainException("You cannot order from your own business.");
        }

        var business = await dbContext.Businesses.AsNoTracking().FirstAsync(b => b.OwnerUserId == post.OwnerUserId, cancellationToken);
        var accepted = method == MarketplacePaymentMethod.Online ? business.AcceptsOnlinePay && gateway.IsReady : business.AcceptsCashOnDelivery;
        if (!accepted)
        {
            throw new DomainException(method == MarketplacePaymentMethod.Online
                ? "This seller does not take online payment just now. Choose cash on delivery."
                : "This seller takes online payment only.");
        }

        var person = await directory.GetCurrentPersonAsync(cancellationToken);
        var phone = string.IsNullOrWhiteSpace(request.Phone) ? person?.Phone : request.Phone.Trim();
        if (string.IsNullOrWhiteSpace(phone))
        {
            throw new DomainException("Enter a mobile number the courier can call.");
        }

        var order = await dbContext.WithOwnerLockAsync(post.OwnerUserId, async () =>
        {
            // Read again under the lock: two customers buying the last piece cannot both get it.
            var tracked = await dbContext.Posts.Include(p => p.Variants).FirstAsync(p => p.Id == post.Id, cancellationToken);
            MarketplacePostVariant? variant = null;
            if (tracked.Variants.Count != 0)
            {
                var main = tracked.MainVariant;
                variant = tracked.Variants.FirstOrDefault(v => v.Id == request.VariantId && (v == main || v.IsActive))
                    ?? throw new DomainException("Choose a colour or size that is on sale.");
            }
            else if (request.VariantId is not null)
            {
                throw new DomainException("This product has no colours or sizes.");
            }

            MarketplaceOrderCore.Hold(tracked, variant, request.Quantity);
            var unitPrice = variant?.Price ?? tracked.Price
                ?? throw new DomainException("This product has no price yet.");

            var created = new MarketplaceOrder
            {
                PostId = tracked.Id,
                VariantId = variant?.Id,
                OwnerUserId = tracked.OwnerUserId,
                CustomerUserId = customerId,
                CustomerName = person?.Name ?? "Customer",
                CustomerPhone = phone,
                DeliveryAddress = request.DeliveryAddress.Trim(),
                Pincode = request.Pincode.Trim(),
                Title = tracked.Title,
                VariantName = variant is null || variant.Name.Length == 0 ? null : variant.Name,
                Quantity = request.Quantity,
                UnitPrice = unitPrice,
                Amount = unitPrice * request.Quantity,
                PaymentMethod = method,
                PayBy = method == MarketplacePaymentMethod.Online ? now.AddMinutes(settings.Value.PaymentHoldMinutes) : null,
            };
            created.MoveTo(
                method == MarketplacePaymentMethod.Online ? MarketplaceOrderStatus.AwaitingPayment : MarketplaceOrderStatus.Placed,
                Customer,
                customerId,
                now);
            dbContext.Orders.Add(created);
            await dbContext.SaveChangesAsync(cancellationToken);
            return created;
        }, cancellationToken);

        return await ReadAsync(order, cancellationToken);
    }

    public async Task<MarketplaceCheckoutDto> Handle(StartMarketplaceOrderPaymentCommand request, CancellationToken cancellationToken)
    {
        var order = await dbContext.AccessibleOrderAsync(request.Id, currentUser.OwnerId(), Customer, cancellationToken);
        if (order.Status != MarketplaceOrderStatus.AwaitingPayment)
        {
            throw new DomainException("Nothing is waiting to be paid on this order.");
        }

        if (order.PayBy <= clock.GetUtcNow())
        {
            throw new DomainException("The time to pay has passed, so the order was let go. Order again.");
        }

        if (!gateway.IsReady)
        {
            throw new DomainException("Online payment is not available just now. Cancel and order with cash on delivery.");
        }

        var description = $"{order.Quantity} × {order.Title}";

        // One gateway order per Marketplace order: paying again after closing the window reuses it.
        if (order.ProviderOrderId is null)
        {
            order.ProviderOrderId = await gateway.CreateOrderAsync(order.Amount, order.Id.ToString("N"), description, cancellationToken);
            await dbContext.SaveChangesAsync(cancellationToken);
        }

        return new MarketplaceCheckoutDto
        {
            ProviderOrderId = order.ProviderOrderId,
            KeyId = gateway.KeyId,
            Amount = order.Amount,
            Description = description,
            NothingToCollect = gateway.IsSimulated,
        };
    }

    public async Task<MarketplaceOrderDto> Handle(CompleteMarketplaceOrderPaymentCommand request, CancellationToken cancellationToken)
    {
        var customerId = currentUser.OwnerId();
        var order = await dbContext.AccessibleOrderAsync(request.Id, customerId, Customer, cancellationToken);
        if (order.ProviderOrderId is null || order.ProviderOrderId != request.ProviderOrderId)
        {
            throw new DomainException("That payment is not for this order.");
        }

        if (!gateway.VerifySignature(order.ProviderOrderId, request.PaymentId, request.Signature))
        {
            throw new DomainException("We could not confirm this payment. If money left your account, it is given back within a few days.");
        }

        await RecordPaymentAsync(dbContext, gateway, order, request.PaymentId, customerId, clock.GetUtcNow(), cancellationToken);
        return await ReadAsync(order, cancellationToken);
    }

    public async Task<MarketplaceOrderDto> Handle(CancelMarketplaceOrderCommand request, CancellationToken cancellationToken)
    {
        var customerId = currentUser.OwnerId();
        var now = clock.GetUtcNow();
        var order = await dbContext.AccessibleOrderAsync(request.Id, customerId, Customer, cancellationToken);
        if (order.Status == MarketplaceOrderStatus.Cancelled)
        {
            return await ReadAsync(order, cancellationToken);
        }

        var lookups = await MarketplaceOrderLookups.LoadAsync(reference, cancellationToken);
        if (lookups.Step(order.Status, MarketplaceOrderStatus.Cancelled, Customer) is null)
        {
            throw new DomainException("This order has shipped, so it can no longer be cancelled.");
        }

        await dbContext.WithOwnerLockAsync(order.OwnerUserId, async () =>
        {
            await dbContext.CancelAsync(order, Customer, customerId, now, cancellationToken);
            await dbContext.SaveChangesAsync(cancellationToken);
            return true;
        }, cancellationToken);

        if (await gateway.TryRefundAsync(order, cancellationToken))
        {
            await dbContext.SaveChangesAsync(cancellationToken);
        }

        return await ReadAsync(order, cancellationToken);
    }

    public async Task<MarketplaceOrderDto> Handle(ReviewMarketplaceOrderCommand request, CancellationToken cancellationToken)
    {
        var customerId = currentUser.OwnerId();
        var now = clock.GetUtcNow();
        var order = await dbContext.AccessibleOrderAsync(request.Id, customerId, Customer, cancellationToken);
        if (order.RatingScore is not null)
        {
            throw new DomainException("You have already reviewed this order.");
        }

        if (order.Status != MarketplaceOrderStatus.Delivered)
        {
            throw new DomainException("You can review an order once it is delivered.");
        }

        order.RatingScore = request.Score;
        order.RatingComment = string.IsNullOrWhiteSpace(request.Comment) ? null : request.Comment.Trim();
        order.RatedAt = now;
        order.ClosedAt = now;
        dbContext.OrderEvents.Add(order.MoveTo(MarketplaceOrderStatus.Closed, Customer, customerId, now, $"{request.Score} stars"));
        await dbContext.SaveChangesAsync(cancellationToken);
        return await ReadAsync(order, cancellationToken);
    }

    public async Task<MarketplaceOrderPageDto> Handle(GetMyMarketplaceOrdersQuery request, CancellationToken cancellationToken)
    {
        var customerId = currentUser.OwnerId();
        var (page, pageSize) = MarketplaceQueries.Paging(request.Page, request.PageSize, settings.Value);
        var lookups = await MarketplaceOrderLookups.LoadAsync(reference, cancellationToken);
        var all = dbContext.Orders.AsNoTracking().Where(o => o.CustomerUserId == customerId);

        // The chips count every order of the customer's, whichever one is chosen; one grouped read.
        var counts = await all
            .GroupBy(o => o.Status)
            .Select(g => new { g.Key, Count = g.Count() })
            .ToDictionaryAsync(x => x.Key, x => x.Count, cancellationToken);

        var mine = Enum.TryParse<MarketplaceOrderStatus>(request.Status, true, out var status) ? all.Where(o => o.Status == status) : all;
        var total = request.Status is null ? counts.Values.Sum() : counts.GetValueOrDefault(status);
        var orders = total == 0
            ? []
            : await mine.OrderByDescending(o => o.CreatedDate).ThenBy(o => o.Id).Skip((page - 1) * pageSize).Take(pageSize).ToListAsync(cancellationToken);
        var images = await dbContext.ImagesAsync(orders, cancellationToken);
        var sellers = await dbContext.SellerNamesAsync(orders, cancellationToken);

        return new MarketplaceOrderPageDto
        {
            Items = orders
                .Select(o =>
                {
                    var dto = o.ToDto(Customer, lookups, images.GetValueOrDefault(o.Id), withHistory: false);
                    dto.SellerName = sellers.GetValueOrDefault(o.OwnerUserId);
                    return dto;
                })
                .ToList(),
            Page = page,
            PageSize = pageSize,
            TotalCount = total,
            Counts = MarketplaceOrderCore.CustomerCounts(lookups, counts),
        };
    }

    public async Task<MarketplaceOrderDto> Handle(GetMyMarketplaceOrderQuery request, CancellationToken cancellationToken)
    {
        var order = await dbContext.AccessibleOrderAsync(request.Id, currentUser.OwnerId(), Customer, cancellationToken);
        return await ReadAsync(order, cancellationToken);
    }

    /// <summary>
    /// Counts one proven payment on its order and confirms it. Paid after it was already let go, the
    /// money is owed back. Reported twice, it counts once.
    /// </summary>
    internal static async Task RecordPaymentAsync(
        IMarketplaceDbContext dbContext,
        IMarketplacePaymentGateway gateway,
        MarketplaceOrder order,
        string paymentId,
        Guid? actorUserId,
        DateTimeOffset now,
        CancellationToken cancellationToken)
    {
        if (order.ProviderPaymentId is not null)
        {
            return;
        }

        order.ProviderPaymentId = paymentId;
        order.PaidAt = now;
        if (order.Status == MarketplaceOrderStatus.AwaitingPayment)
        {
            order.PayBy = null;
            dbContext.OrderEvents.Add(order.MoveTo(MarketplaceOrderStatus.Confirmed, MarketplaceOrderActor.Customer, actorUserId, now, "Paid online"));
            await dbContext.SaveChangesAsync(cancellationToken);
            return;
        }

        // The order was let go before the payment arrived: the money moved, so it goes back.
        order.RefundDue = order.Status == MarketplaceOrderStatus.Cancelled;
        await dbContext.SaveChangesAsync(cancellationToken);
        if (await gateway.TryRefundAsync(order, cancellationToken))
        {
            await dbContext.SaveChangesAsync(cancellationToken);
        }
    }

    private async Task<MarketplaceOrderDto> ReadAsync(MarketplaceOrder order, CancellationToken cancellationToken)
    {
        var lookups = await MarketplaceOrderLookups.LoadAsync(reference, cancellationToken);
        var images = await dbContext.ImagesAsync([order], cancellationToken);
        var sellers = await dbContext.SellerNamesAsync([order], cancellationToken);
        var dto = order.ToDto(Customer, lookups, images.GetValueOrDefault(order.Id), withHistory: true);
        dto.SellerName = sellers.GetValueOrDefault(order.OwnerUserId);
        return dto;
    }
}

/// <summary>What the timed job did in one run.</summary>
public record MarketplaceOrderJobResult(int Lapsed, int Closed, int Refunded)
{
    public int Total => Lapsed + Closed + Refunded;
}

/// <summary>
/// The timed job, every minute: online orders not paid in time are let go (unless the gateway says
/// they were paid), delivered orders close after their review days, and owed refunds are retried.
/// </summary>
public class RunMarketplaceOrderJobsCommand : IRequest<MarketplaceOrderJobResult>
{
    /// <summary>How many orders of each kind one run handles; the rest wait for the next minute.</summary>
    public int BatchSize { get; set; } = 100;
}

public class RunMarketplaceOrderJobsHandler(
    IMarketplaceDbContext dbContext,
    IMarketplacePaymentGateway gateway,
    TimeProvider clock) : IRequestHandler<RunMarketplaceOrderJobsCommand, MarketplaceOrderJobResult>
{
    public async Task<MarketplaceOrderJobResult> Handle(RunMarketplaceOrderJobsCommand request, CancellationToken cancellationToken)
    {
        var now = clock.GetUtcNow();
        var lapsed = 0;
        var closed = 0;
        var refunded = 0;

        var unpaid = await dbContext.Orders.Include(o => o.Events)
            .Where(o => o.Status == MarketplaceOrderStatus.AwaitingPayment && o.PayBy <= now)
            .OrderBy(o => o.PayBy)
            .Take(request.BatchSize)
            .ToListAsync(cancellationToken);
        foreach (var order in unpaid)
        {
            // Paid in the customer's UPI app, but their app closed before telling us: confirm, not let go.
            string? paymentId;
            try
            {
                paymentId = order.ProviderOrderId is null ? null : await gateway.FindCapturedPaymentAsync(order.ProviderOrderId, cancellationToken);
            }
            catch (Exception exception) when (exception is not OperationCanceledException)
            {
                // Could not ask: not let go yet; the next minute asks again.
                continue;
            }

            if (paymentId is not null)
            {
                await CustomerMarketplaceOrderHandlers.RecordPaymentAsync(dbContext, gateway, order, paymentId, null, now, cancellationToken);
                continue;
            }

            await dbContext.WithOwnerLockAsync(order.OwnerUserId, async () =>
            {
                await dbContext.CancelAsync(order, MarketplaceOrderActor.System, null, now, cancellationToken, "Not paid in time");
                await dbContext.SaveChangesAsync(cancellationToken);
                return true;
            }, cancellationToken);
            lapsed++;
        }

        var delivered = await dbContext.Orders.Include(o => o.Events)
            .Where(o => o.Status == MarketplaceOrderStatus.Delivered && o.ClosesAt <= now)
            .OrderBy(o => o.ClosesAt)
            .Take(request.BatchSize)
            .ToListAsync(cancellationToken);
        foreach (var order in delivered)
        {
            order.ClosedAt = now;
            dbContext.OrderEvents.Add(order.MoveTo(MarketplaceOrderStatus.Closed, MarketplaceOrderActor.System, null, now, "No review"));
            closed++;
        }

        if (closed > 0)
        {
            await dbContext.SaveChangesAsync(cancellationToken);
        }

        var owed = await dbContext.Orders
            .Where(o => o.RefundDue && o.RefundId == null && o.ProviderPaymentId != null)
            .OrderBy(o => o.CancelledAt)
            .Take(request.BatchSize)
            .ToListAsync(cancellationToken);
        foreach (var order in owed)
        {
            if (await gateway.TryRefundAsync(order, cancellationToken))
            {
                await dbContext.SaveChangesAsync(cancellationToken);
                refunded++;
            }
        }

        return new MarketplaceOrderJobResult(lapsed, closed, refunded);
    }
}
