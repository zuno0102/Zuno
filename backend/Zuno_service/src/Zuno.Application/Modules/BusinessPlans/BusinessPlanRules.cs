using Microsoft.EntityFrameworkCore;
using Zuno.Application.Common.Interfaces;
using Zuno.Domain.Entities;
using Zuno.Domain.Enums;
using Zuno.Domain.Exceptions;

namespace Zuno.Application.Modules.BusinessPlans;

/// <summary>Whether one more live listing may go up in an area, and why not.</summary>
public record ListingAllowance(bool Allowed, string? Reason);

/// <summary>
/// The one rule over all three areas. A listing may go up in an area when a running paid plan
/// includes that area, or when the business's live listings in all areas together are under the
/// Basic plan's limit (1). Service holds the plan; Rent and Marketplace ask it before a listing goes live.
/// </summary>
public sealed class BusinessPlanRules(IApplicationDbContext dbContext, IAreaListings areaListings)
{
    public static readonly ListingArea[] Areas = [ListingArea.Service, ListingArea.Rent, ListingArea.Marketplace];

    public static string AreaName(ListingArea area) => area switch
    {
        ListingArea.Service => "Service",
        ListingArea.Rent => "Rent",
        _ => "Marketplace",
    };

    /// <summary>Paid plans running now, latest end first.</summary>
    public Task<List<BusinessSubscription>> RunningAsync(Guid ownerUserId, DateTimeOffset now, CancellationToken cancellationToken) =>
        dbContext.BusinessSubscriptions
            .Where(s => s.OwnerUserId == ownerUserId && s.State == SubscriptionStatus.Active && s.StartsAt <= now && s.EndsAt > now)
            .OrderByDescending(s => s.EndsAt)
            .ToListAsync(cancellationToken);

    public async Task<SubscriptionPlan> BasicAsync(CancellationToken cancellationToken) =>
        await dbContext.SubscriptionPlans.AsNoTracking().FirstOrDefaultAsync(p => p.IsDefault, cancellationToken)
        ?? throw new InvalidOperationException("No Basic plan is set up.");

    /// <summary>The business's live services, oldest first.</summary>
    public Task<List<AreaListing>> LiveServicesAsync(Guid ownerUserId, CancellationToken cancellationToken) =>
        dbContext.BusinessServices
            .Where(s => s.BusinessOwnerProfile.UserId == ownerUserId && s.IsActive)
            .OrderBy(s => s.CreatedDate)
            .Select(s => new AreaListing(s.Id, s.CreatedDate))
            .ToListAsync(cancellationToken);

    /// <summary>An area's live listings, from this database for Service or from the area's API.</summary>
    public async Task<IReadOnlyList<AreaListing>> LiveAsync(ListingArea area, Guid ownerUserId, CancellationToken cancellationToken) =>
        area == ListingArea.Service
            ? await LiveServicesAsync(ownerUserId, cancellationToken)
            : await areaListings.LiveAsync(area, ownerUserId, cancellationToken);

    /// <summary>
    /// May one more listing go live in <paramref name="area"/>? <paramref name="liveHere"/> is the
    /// asking API's own count, so it is not asked back. Throws <see cref="AreaUnavailableException"/>
    /// when another area's count is needed and cannot be read.
    /// </summary>
    public async Task<ListingAllowance> CheckAsync(
        Guid ownerUserId, ListingArea area, int? liveHere, DateTimeOffset now, CancellationToken cancellationToken)
    {
        var running = await RunningAsync(ownerUserId, now, cancellationToken);
        if (running.Any(s => s.Includes(area)))
        {
            return new ListingAllowance(true, null);
        }

        var basic = await BasicAsync(cancellationToken);
        var limit = basic.MaxLiveListings ?? int.MaxValue;
        var total = 0;
        foreach (var each in Areas)
        {
            total += each == area && liveHere is { } known
                ? known
                : (await LiveAsync(each, ownerUserId, cancellationToken)).Count;
            if (total >= limit)
            {
                return new ListingAllowance(false, LimitReason(area, limit, running.Count > 0));
            }
        }

        return new ListingAllowance(true, null);
    }

    /// <summary>Throws <see cref="PlanLimitException"/> unless one more listing may go live in <paramref name="area"/>.</summary>
    public async Task EnsureCanAddAsync(Guid ownerUserId, ListingArea area, int? liveHere, DateTimeOffset now, CancellationToken cancellationToken)
    {
        ListingAllowance allowance;
        try
        {
            allowance = await CheckAsync(ownerUserId, area, liveHere, now, cancellationToken);
        }
        catch (AreaUnavailableException)
        {
            throw new DomainException("We couldn't check your plan just now. Try again in a minute.");
        }

        if (!allowance.Allowed)
        {
            throw new PlanLimitException(allowance.Reason!);
        }
    }

    private static string LimitReason(ListingArea area, int limit, bool hasPaidPlan) =>
        hasPaidPlan
            ? $"Your plan does not include {AreaName(area)}. Get a plan with {AreaName(area)} to list here."
            : $"The Basic plan allows {limit} live listing{(limit == 1 ? string.Empty : "s")} in total. Get a plan with {AreaName(area)} to add more.";
}
