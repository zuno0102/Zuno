using FluentValidation;
using MediatR;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Options;
using Zuno.Application.Common.Interfaces;
using Zuno.Application.Common.Settings;
using Zuno.Domain.Entities;
using Zuno.Domain.Enums;
using Zuno.Domain.Exceptions;

namespace Zuno.Application.Modules.BusinessPlans;

public record GetMyBusinessPlanQuery : IRequest<BusinessPlanDto>;

/// <summary>Starts buying a plan: a Razorpay order for its price as it stands now.</summary>
public record StartPlanPurchaseCommand(Guid PlanId) : IRequest<PlanPaymentDto>;

/// <summary>The business paid; the signature proves it, then the plan runs.</summary>
public record ConfirmPlanPurchaseCommand(Guid SubscriptionId, string? ProviderPaymentId, string? Signature) : IRequest<BusinessPlanDto>;

/// <summary>Rent or Marketplace asking whether one more listing may go live; <see cref="LiveHere"/> is its own count.</summary>
public record CheckListingAllowanceQuery(ListingArea Area, int LiveHere) : IRequest<ListingAllowanceDto>;

public class StartPlanPurchaseCommandValidator : AbstractValidator<StartPlanPurchaseCommand>
{
    public StartPlanPurchaseCommandValidator() => RuleFor(x => x.PlanId).NotEmpty();
}

public class CheckListingAllowanceQueryValidator : AbstractValidator<CheckListingAllowanceQuery>
{
    public CheckListingAllowanceQueryValidator()
    {
        RuleFor(x => x.Area).IsInEnum();
        RuleFor(x => x.LiveHere).GreaterThanOrEqualTo(0);
    }
}

public class BusinessPlanHandlers(
    ICurrentUserService currentUser,
    IApplicationDbContext dbContext,
    IDateTimeProvider clock,
    IPayoutProvider paymentProvider,
    IOptions<RazorpaySettings> razorpaySettings,
    BusinessPlanRules rules,
    PlanReconciler reconciler) :
    IRequestHandler<GetMyBusinessPlanQuery, BusinessPlanDto>,
    IRequestHandler<StartPlanPurchaseCommand, PlanPaymentDto>,
    IRequestHandler<ConfirmPlanPurchaseCommand, BusinessPlanDto>,
    IRequestHandler<CheckListingAllowanceQuery, ListingAllowanceDto>
{
    private Guid Owner => currentUser.UserId ?? throw new UnauthorizedAccessException("User is not authenticated.");

    public async Task<BusinessPlanDto> Handle(GetMyBusinessPlanQuery request, CancellationToken cancellationToken) =>
        await ReadAsync(Owner, clock.UtcNow, cancellationToken);

    public async Task<PlanPaymentDto> Handle(StartPlanPurchaseCommand request, CancellationToken cancellationToken)
    {
        var owner = Owner;
        var plan = await dbContext.SubscriptionPlans.AsNoTracking()
            .FirstOrDefaultAsync(p => p.Id == request.PlanId && p.IsActive && !p.IsDefault, cancellationToken)
            ?? throw new DomainException("This plan is not on sale any more. Pick another.");

        // An unpaid start of the same plan at the same price is handed back, so a second tap never
        // raises a second order. A price change since starts afresh at the new price.
        var purchase = await dbContext.BusinessSubscriptions
            .Where(s => s.OwnerUserId == owner && s.PlanId == plan.Id && s.State == SubscriptionStatus.AwaitingPayment)
            .OrderByDescending(s => s.CreatedDate)
            .FirstOrDefaultAsync(cancellationToken);
        if (purchase is null || purchase.Amount != plan.Price || purchase.DurationDays != plan.DurationDays)
        {
            purchase = BusinessSubscription.Start(owner, plan);
            dbContext.BusinessSubscriptions.Add(purchase);
        }

        var result = new PlanPaymentDto
        {
            SubscriptionId = purchase.Id,
            PlanName = purchase.PlanName,
            Amount = purchase.Amount,
            DurationDays = purchase.DurationDays,
        };

        if (purchase.Amount == 0m)
        {
            await reconciler.StartAsync(purchase, null, clock.UtcNow, cancellationToken);
            result.NothingToCollect = true;
            return result;
        }

        if (purchase.PendingOrderId is null)
        {
            var order = await paymentProvider.CreateCollectionOrderAsync(
                purchase.Amount, purchase.PaymentKey, $"Zuno plan: {purchase.PlanName}", cancellationToken);
            // Empty when collection is simulated; stored so confirming knows an order was raised.
            purchase.PendingOrderId = order.ProviderOrderId;
        }

        await dbContext.SaveChangesAsync(cancellationToken);
        result.ProviderOrderId = purchase.PendingOrderId is { Length: > 0 } id ? id : null;
        result.RazorpayKeyId = result.ProviderOrderId is null ? null : razorpaySettings.Value.KeyId;
        result.NothingToCollect = result.ProviderOrderId is null;
        return result;
    }

    public async Task<BusinessPlanDto> Handle(ConfirmPlanPurchaseCommand request, CancellationToken cancellationToken)
    {
        var owner = Owner;
        var purchase = await dbContext.BusinessSubscriptions
            .FirstOrDefaultAsync(s => s.Id == request.SubscriptionId && s.OwnerUserId == owner, cancellationToken)
            ?? throw new EntityNotFoundException(nameof(BusinessSubscription), request.SubscriptionId);

        // The same payment confirmed twice (a retry, a double tap) activates once.
        if (purchase.State != SubscriptionStatus.AwaitingPayment)
        {
            if (request.ProviderPaymentId is { Length: > 0 } repeated && repeated == purchase.PaymentId)
            {
                return await ReadAsync(owner, clock.UtcNow, cancellationToken);
            }

            throw new DomainException("This plan purchase is already settled. Open the plans again.");
        }

        switch (purchase.PendingOrderId)
        {
            case null:
                throw new DomainException("There is no payment waiting for this plan. Start again.");
            case "" when !razorpaySettings.Value.SimulateCollection:
                throw new DomainException("This payment could not be verified. Start again.");
            case "":
                break;
            case var orderId when !paymentProvider.VerifyPaymentSignature(
                orderId, request.ProviderPaymentId ?? string.Empty, request.Signature ?? string.Empty):
                throw new DomainException("This payment could not be verified with Razorpay. Your plan is not active yet; try paying again.");
        }

        await reconciler.StartAsync(purchase, request.ProviderPaymentId, clock.UtcNow, cancellationToken);
        return await ReadAsync(owner, clock.UtcNow, cancellationToken);
    }

    public async Task<ListingAllowanceDto> Handle(CheckListingAllowanceQuery request, CancellationToken cancellationToken)
    {
        try
        {
            var allowance = await rules.CheckAsync(Owner, request.Area, request.LiveHere, clock.UtcNow, cancellationToken);
            return new ListingAllowanceDto { Allowed = allowance.Allowed, Reason = allowance.Reason };
        }
        catch (AreaUnavailableException)
        {
            throw new DomainException("We couldn't check your plan just now. Try again in a minute.");
        }
    }

    private async Task<BusinessPlanDto> ReadAsync(Guid owner, DateTimeOffset now, CancellationToken cancellationToken)
    {
        var running = await rules.RunningAsync(owner, now, cancellationToken);
        var basic = await rules.BasicAsync(cancellationToken);
        var current = running.FirstOrDefault();

        // A renewal starts where the running plan ends, so the business's plan runs to the last end.
        var lastEnd = await dbContext.BusinessSubscriptions
            .Where(s => s.OwnerUserId == owner && s.State == SubscriptionStatus.Active && s.EndsAt > now)
            .MaxAsync(s => s.EndsAt, cancellationToken);
        var dto = new BusinessPlanDto
        {
            PlanName = current?.PlanName ?? basic.Name,
            IsBasic = current is null,
            EndsAt = current is null ? null : lastEnd,
            IncludesService = running.Any(s => s.IncludesService),
            IncludesRent = running.Any(s => s.IncludesRent),
            IncludesMarketplace = running.Any(s => s.IncludesMarketplace),
            BasicLimit = basic.MaxLiveListings ?? 0,
            PausedCount = await dbContext.PlanPausedListings.CountAsync(p => p.OwnerUserId == owner, cancellationToken),
        };

        var counts = new Dictionary<ListingArea, int?>();
        foreach (var area in BusinessPlanRules.Areas)
        {
            try
            {
                counts[area] = (await rules.LiveAsync(area, owner, cancellationToken)).Count;
            }
            catch (AreaUnavailableException)
            {
                counts[area] = null;
            }
        }

        foreach (var area in BusinessPlanRules.Areas)
        {
            var usage = new AreaUsageDto { Area = area.ToString(), LiveCount = counts[area] };
            if (running.Any(s => s.Includes(area)))
            {
                usage.CanAdd = true;
            }
            else if (counts.Values.Any(c => c is null))
            {
                usage.Reason = "We couldn't check your plan just now. Try again in a minute.";
            }
            else
            {
                var limit = basic.MaxLiveListings ?? int.MaxValue;
                usage.CanAdd = counts.Values.Sum(c => c!.Value) < limit;
                usage.Reason = usage.CanAdd
                    ? null
                    : running.Count > 0
                        ? $"Your plan does not include {BusinessPlanRules.AreaName(area)}."
                        : $"The Basic plan allows {limit} live listing{(limit == 1 ? string.Empty : "s")} in total.";
            }

            dto.Areas.Add(usage);
        }

        dto.Plans = await dbContext.SubscriptionPlans.AsNoTracking()
            .Where(p => p.IsActive && !p.IsDefault)
            .OrderBy(p => p.SortOrder)
            .Select(p => new PlanOfferDto
            {
                Id = p.Id,
                Code = p.Code,
                Name = p.Name,
                Period = p.Period.ToString(),
                Price = p.Price,
                DurationDays = p.DurationDays ?? 0,
                IncludesService = p.IncludesService,
                IncludesRent = p.IncludesRent,
                IncludesMarketplace = p.IncludesMarketplace,
            })
            .ToListAsync(cancellationToken);
        return dto;
    }
}
