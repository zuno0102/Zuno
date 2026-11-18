using FluentValidation;
using MediatR;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Options;
using Zuno.Marketplace.Application.Common;
using Zuno.Marketplace.Domain.Entities;
using Zuno.Marketplace.Domain.Enums;
using Zuno.Marketplace.Domain.Exceptions;

namespace Zuno.Marketplace.Application.Orders;

/// <summary>One page of the business's product orders, narrowed to a status, with a count per status.</summary>
public class GetBusinessMarketplaceOrdersQuery : IRequest<MarketplaceOrderPageDto>
{
    /// <summary>E.g. <c>Placed</c>; null for every order.</summary>
    public string? Status { get; set; }

    public int Page { get; set; } = 1;

    public int? PageSize { get; set; }
}

public class GetBusinessMarketplaceOrderQuery : IRequest<MarketplaceOrderDto>
{
    public Guid Id { get; set; }
}

/// <summary>A one-tap step by the business — Confirm order, Out for delivery, Mark delivered.</summary>
public class ChangeMarketplaceOrderStatusCommand : IRequest<MarketplaceOrderDto>
{
    public Guid Id { get; set; }

    public string Status { get; set; } = string.Empty;
}

/// <summary>Mark shipped: the courier it went with and its tracking number.</summary>
public class ShipMarketplaceOrderCommand : IRequest<MarketplaceOrderDto>
{
    public Guid Id { get; set; }

    /// <summary>A courier row's code, e.g. <c>dtdc</c>, or <c>other</c>.</summary>
    public string CourierCode { get; set; } = string.Empty;

    /// <summary>Only for "Other": the courier's name as the business knows it.</summary>
    public string? CourierName { get; set; }

    public string TrackingNumber { get; set; } = string.Empty;
}

/// <summary>A photo of the courier's receipt, after the order has shipped.</summary>
public class SetMarketplaceOrderReceiptCommand : IRequest<MarketplaceOrderDto>
{
    public Guid OrderId { get; set; }

    public Stream Content { get; set; } = Stream.Null;

    /// <summary>Chosen by the server from the file's bytes, with the dot, e.g. <c>.jpg</c>.</summary>
    public string FileExtension { get; set; } = ".jpg";
}

public class GetMarketplacePaymentSettingsQuery : IRequest<MarketplacePaymentSettingsDto>;

public class UpdateMarketplacePaymentSettingsCommand : IRequest<MarketplacePaymentSettingsDto>
{
    public bool AcceptsCashOnDelivery { get; set; }

    public bool AcceptsOnlinePay { get; set; }
}

public class GetBusinessMarketplaceOrdersQueryValidator : AbstractValidator<GetBusinessMarketplaceOrdersQuery>
{
    public GetBusinessMarketplaceOrdersQueryValidator() =>
        RuleFor(x => x.Status)
            .Must(s => MarketplaceOrderParsing.Status(s) is not null)
            .When(x => !string.IsNullOrWhiteSpace(x.Status))
            .WithMessage("Unknown order status.");
}

public class ChangeMarketplaceOrderStatusCommandValidator : AbstractValidator<ChangeMarketplaceOrderStatusCommand>
{
    public ChangeMarketplaceOrderStatusCommandValidator()
    {
        RuleFor(x => x.Id).NotEmpty();
        RuleFor(x => x.Status).Must(s => MarketplaceOrderParsing.Status(s) is not null).WithMessage("Unknown order status.");
    }
}

public class ShipMarketplaceOrderCommandValidator : AbstractValidator<ShipMarketplaceOrderCommand>
{
    public ShipMarketplaceOrderCommandValidator()
    {
        RuleFor(x => x.Id).NotEmpty();
        RuleFor(x => x.CourierCode).NotEmpty().WithMessage("Choose the courier.").MaximumLength(40);
        RuleFor(x => x.CourierName).MaximumLength(MarketplaceOrderLimits.CourierNameLength);
        RuleFor(x => x.TrackingNumber)
            .Cascade(CascadeMode.Stop)
            .Must(n => !string.IsNullOrWhiteSpace(n)).WithMessage("Enter the tracking number from the courier's receipt.")
            .Must(n => n.Trim().Length <= MarketplaceOrderLimits.TrackingNumberLength)
            .WithMessage($"A tracking number is at most {MarketplaceOrderLimits.TrackingNumberLength} letters and digits.")
            .Must(n => System.Text.RegularExpressions.Regex.IsMatch(n.Trim(), MarketplaceOrderLimits.TrackingNumberPattern))
            .WithMessage("A tracking number has only letters, digits and dashes.");
    }
}

public class SetMarketplaceOrderReceiptCommandValidator : AbstractValidator<SetMarketplaceOrderReceiptCommand>
{
    public SetMarketplaceOrderReceiptCommandValidator()
    {
        RuleFor(x => x.OrderId).NotEmpty();
        RuleFor(x => x.FileExtension).NotEmpty().MaximumLength(10);
    }
}

public class UpdateMarketplacePaymentSettingsCommandValidator : AbstractValidator<UpdateMarketplacePaymentSettingsCommand>
{
    public UpdateMarketplacePaymentSettingsCommandValidator() =>
        RuleFor(x => x)
            .Must(x => x.AcceptsCashOnDelivery || x.AcceptsOnlinePay)
            .WithMessage("Keep at least one way for customers to pay.");
}

internal static class MarketplaceOrderParsing
{
    public static MarketplaceOrderStatus? Status(string? value) =>
        Enum.TryParse<MarketplaceOrderStatus>(value, true, out var status) && Enum.IsDefined(status) ? status : null;

    public static MarketplacePaymentMethod? PaymentMethod(string? value) =>
        Enum.TryParse<MarketplacePaymentMethod>(value, true, out var method) && Enum.IsDefined(method) ? method : null;
}

/// <summary>The business's side of product orders. The owner is always the signed-in business.</summary>
public class BusinessMarketplaceOrderHandlers(
    ICurrentUser currentUser,
    IMarketplaceDbContext dbContext,
    IMarketplaceMediaStorage storage,
    IMarketplacePaymentGateway gateway,
    IServiceDirectory directory,
    MarketplaceReference reference,
    TimeProvider clock,
    IOptions<MarketplaceSettings> settings) :
    IRequestHandler<GetBusinessMarketplaceOrdersQuery, MarketplaceOrderPageDto>,
    IRequestHandler<GetBusinessMarketplaceOrderQuery, MarketplaceOrderDto>,
    IRequestHandler<ChangeMarketplaceOrderStatusCommand, MarketplaceOrderDto>,
    IRequestHandler<ShipMarketplaceOrderCommand, MarketplaceOrderDto>,
    IRequestHandler<SetMarketplaceOrderReceiptCommand, MarketplaceOrderDto>,
    IRequestHandler<GetMarketplacePaymentSettingsQuery, MarketplacePaymentSettingsDto>,
    IRequestHandler<UpdateMarketplacePaymentSettingsCommand, MarketplacePaymentSettingsDto>
{
    private const MarketplaceOrderActor Business = MarketplaceOrderActor.Business;

    public async Task<MarketplaceOrderPageDto> Handle(GetBusinessMarketplaceOrdersQuery request, CancellationToken cancellationToken)
    {
        var ownerId = currentUser.OwnerId();
        var (page, pageSize) = MarketplaceQueries.Paging(request.Page, request.PageSize, settings.Value);
        var lookups = await MarketplaceOrderLookups.LoadAsync(reference, cancellationToken);
        var mine = dbContext.Orders.AsNoTracking().Where(o => o.OwnerUserId == ownerId);

        var counts = await mine.GroupBy(o => o.Status)
            .Select(g => new { g.Key, Count = g.Count() })
            .ToDictionaryAsync(g => g.Key, g => g.Count, cancellationToken);

        var filtered = MarketplaceOrderParsing.Status(request.Status) is { } status ? mine.Where(o => o.Status == status) : mine;
        var total = await filtered.CountAsync(cancellationToken);
        var orders = await filtered
            .OrderByDescending(o => o.CreatedDate)
            .Skip((page - 1) * pageSize)
            .Take(pageSize)
            .ToListAsync(cancellationToken);
        var images = await dbContext.ImagesAsync(orders, cancellationToken);

        return new MarketplaceOrderPageDto
        {
            Items = orders.Select(o => o.ToDto(Business, lookups, images.GetValueOrDefault(o.Id), withHistory: false)).ToList(),
            Page = page,
            PageSize = pageSize,
            TotalCount = total,
            Counts = MarketplaceOrderCore.Counts(lookups.Statuses.Select(s => s.Code), counts),
        };
    }

    public async Task<MarketplaceOrderDto> Handle(GetBusinessMarketplaceOrderQuery request, CancellationToken cancellationToken)
    {
        var order = await dbContext.AccessibleOrderAsync(request.Id, currentUser.OwnerId(), Business, cancellationToken);
        return await ReadAsync(order, cancellationToken);
    }

    public async Task<MarketplaceOrderDto> Handle(ChangeMarketplaceOrderStatusCommand request, CancellationToken cancellationToken)
    {
        var ownerId = currentUser.OwnerId();
        var now = clock.GetUtcNow();
        var target = MarketplaceOrderParsing.Status(request.Status)!.Value;
        var order = await dbContext.AccessibleOrderAsync(request.Id, ownerId, Business, cancellationToken);
        var lookups = await MarketplaceOrderLookups.LoadAsync(reference, cancellationToken);

        // Sent twice (a double tap, a retry): already done is not an error.
        if (order.Status == target)
        {
            return await ReadAsync(order, cancellationToken);
        }

        var step = lookups.Step(order.Status, target, Business)
            ?? throw new DomainException($"An order that is {Name(lookups, order.Status)} cannot be moved to {Name(lookups, target)}.");
        if (step.NeedsTracking)
        {
            throw new DomainException("Add the courier and its tracking number to mark this order shipped.");
        }

        if (target == MarketplaceOrderStatus.Delivered)
        {
            order.DeliveredAt = now;
            order.ClosesAt = now.AddDays(settings.Value.AutoCloseDays);

            // Cash on delivery: handing it over is when the money is taken.
            if (order.PaymentMethod == MarketplacePaymentMethod.CashOnDelivery)
            {
                order.PaidAt ??= now;
            }
        }

        dbContext.OrderEvents.Add(order.MoveTo(target, Business, ownerId, now));
        await dbContext.SaveChangesAsync(cancellationToken);
        return await ReadAsync(order, cancellationToken);
    }

    public async Task<MarketplaceOrderDto> Handle(ShipMarketplaceOrderCommand request, CancellationToken cancellationToken)
    {
        var ownerId = currentUser.OwnerId();
        var now = clock.GetUtcNow();
        var order = await dbContext.AccessibleOrderAsync(request.Id, ownerId, Business, cancellationToken);
        var lookups = await MarketplaceOrderLookups.LoadAsync(reference, cancellationToken);

        if (lookups.Step(order.Status, MarketplaceOrderStatus.Shipped, Business) is null)
        {
            throw new DomainException($"An order that is {Name(lookups, order.Status)} cannot be marked shipped.");
        }

        var courier = lookups.Couriers.FirstOrDefault(c => c.IsActive && string.Equals(c.Code, request.CourierCode, StringComparison.OrdinalIgnoreCase))
            ?? throw new DomainException("Choose a courier from the list.");
        var courierName = courier.TakesCustomName ? request.CourierName?.Trim() : courier.Name;
        if (string.IsNullOrWhiteSpace(courierName))
        {
            throw new DomainException("Type the courier's name.");
        }

        var trackingNumber = request.TrackingNumber.Trim();
        order.CourierCode = courier.Code;
        order.CourierName = courierName;
        order.TrackingNumber = trackingNumber;
        order.ShippedAt = now;
        dbContext.OrderEvents.Add(order.MoveTo(MarketplaceOrderStatus.Shipped, Business, ownerId, now, $"{courierName} · {trackingNumber}"));
        await dbContext.SaveChangesAsync(cancellationToken);
        return await ReadAsync(order, cancellationToken);
    }

    public async Task<MarketplaceOrderDto> Handle(SetMarketplaceOrderReceiptCommand request, CancellationToken cancellationToken)
    {
        // The order is checked before any file is written.
        var order = await dbContext.AccessibleOrderAsync(request.OrderId, currentUser.OwnerId(), Business, cancellationToken);
        if (order.ShippedAt is null || order.Status == MarketplaceOrderStatus.Cancelled)
        {
            throw new DomainException("Add the courier receipt once the order is marked shipped.");
        }

        var earlier = order.ReceiptUrl;
        order.ReceiptUrl = await storage.SaveOrderReceiptAsync(order.Id, request.Content, request.FileExtension, cancellationToken);
        await dbContext.SaveChangesAsync(cancellationToken);
        if (earlier is not null && earlier != order.ReceiptUrl)
        {
            storage.Delete(earlier);
        }

        return await ReadAsync(order, cancellationToken);
    }

    public async Task<MarketplacePaymentSettingsDto> Handle(GetMarketplacePaymentSettingsQuery request, CancellationToken cancellationToken)
    {
        var ownerId = currentUser.OwnerId();
        var business = await dbContext.Businesses.AsNoTracking().FirstOrDefaultAsync(b => b.OwnerUserId == ownerId, cancellationToken)
            ?? new MarketplaceBusiness();
        return SettingsDto(business);
    }

    public async Task<MarketplacePaymentSettingsDto> Handle(UpdateMarketplacePaymentSettingsCommand request, CancellationToken cancellationToken)
    {
        var ownerId = currentUser.OwnerId();
        var business = await dbContext.Businesses.FirstOrDefaultAsync(b => b.OwnerUserId == ownerId, cancellationToken);
        if (business is null)
        {
            // Not yet known to Marketplace: learn the name from the Service profile, as the tab does.
            var profile = await directory.GetCurrentBusinessAsync(cancellationToken)
                ?? throw new DomainException("Your business profile could not be read just now. Try again in a moment.");
            business = new MarketplaceBusiness
            {
                OwnerUserId = ownerId,
                Name = profile.Name,
                LogoUrl = profile.LogoUrl,
                IsVerified = profile.IsVerified,
                RefreshedAt = clock.GetUtcNow(),
            };
            dbContext.Businesses.Add(business);
        }

        business.AcceptsCashOnDelivery = request.AcceptsCashOnDelivery;
        business.AcceptsOnlinePay = request.AcceptsOnlinePay;
        await dbContext.SaveChangesAsync(cancellationToken);
        return SettingsDto(business);
    }

    private MarketplacePaymentSettingsDto SettingsDto(MarketplaceBusiness business) => new()
    {
        AcceptsCashOnDelivery = business.AcceptsCashOnDelivery,
        AcceptsOnlinePay = business.AcceptsOnlinePay,
        OnlinePayAvailable = gateway.IsReady,
    };

    private async Task<MarketplaceOrderDto> ReadAsync(MarketplaceOrder order, CancellationToken cancellationToken)
    {
        var lookups = await MarketplaceOrderLookups.LoadAsync(reference, cancellationToken);
        var images = await dbContext.ImagesAsync([order], cancellationToken);
        return order.ToDto(Business, lookups, images.GetValueOrDefault(order.Id), withHistory: true);
    }

    private static string Name(MarketplaceOrderLookups lookups, MarketplaceOrderStatus status) =>
        lookups.Statuses.FirstOrDefault(s => s.Code == status)?.Name.ToLowerInvariant() ?? status.ToString();
}
