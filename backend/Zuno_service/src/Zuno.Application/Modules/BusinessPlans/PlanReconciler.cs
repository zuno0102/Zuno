using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;
using Zuno.Application.Common.Interfaces;
using Zuno.Domain.Entities;
using Zuno.Domain.Enums;

namespace Zuno.Application.Modules.BusinessPlans;

/// <summary>
/// What a plan's end and a renewal do to a business's listings. When a plan ends, listings it alone
/// allowed are paused — kept, hidden — leaving the oldest the Basic plan allows; a renewal brings back
/// exactly those. Listings a business had before it ever bought a plan are never touched by a purchase.
/// </summary>
public sealed class PlanReconciler(
    IApplicationDbContext dbContext,
    BusinessPlanRules rules,
    IAreaListings areaListings,
    ILogger<PlanReconciler> logger)
{
    /// <summary>Brings back the listings a plan's end paused, in the areas a running plan now includes.</summary>
    public async Task ResumeCoveredAsync(Guid ownerUserId, DateTimeOffset now, CancellationToken cancellationToken)
    {
        var running = await rules.RunningAsync(ownerUserId, now, cancellationToken);
        var paused = await dbContext.PlanPausedListings
            .Where(p => p.OwnerUserId == ownerUserId)
            .ToListAsync(cancellationToken);
        foreach (var area in paused.Where(p => running.Any(s => s.Includes(p.Area))).GroupBy(p => p.Area))
        {
            await SetLiveAsync(area.Key, ownerUserId, [.. area.Select(p => p.ListingId)], live: true, cancellationToken);
            dbContext.PlanPausedListings.RemoveRange(area);
        }

        await dbContext.SaveChangesAsync(cancellationToken);
    }

    /// <summary>
    /// After a plan ended: listings in areas no running plan includes may stay live only within the
    /// Basic limit, after the covered areas' listings; the oldest stay, the rest are paused and recorded.
    /// </summary>
    public async Task PauseBeyondAllowanceAsync(Guid ownerUserId, DateTimeOffset now, CancellationToken cancellationToken)
    {
        var running = await rules.RunningAsync(ownerUserId, now, cancellationToken);
        var limit = (await rules.BasicAsync(cancellationToken)).MaxLiveListings ?? int.MaxValue;

        var live = new Dictionary<ListingArea, IReadOnlyList<AreaListing>>();
        foreach (var area in BusinessPlanRules.Areas)
        {
            live[area] = await rules.LiveAsync(area, ownerUserId, cancellationToken);
        }

        bool Covered(ListingArea area) => running.Any(s => s.Includes(area));
        var budget = Math.Max(0, limit - live.Where(a => Covered(a.Key)).Sum(a => a.Value.Count));
        var toPause = live
            .Where(a => !Covered(a.Key))
            .SelectMany(a => a.Value.Select(listing => (Area: a.Key, Listing: listing)))
            .OrderBy(x => x.Listing.CreatedDate)
            .Skip(budget)
            .ToList();

        foreach (var area in toPause.GroupBy(x => x.Area))
        {
            var ids = area.Select(x => x.Listing.Id).ToList();
            await SetLiveAsync(area.Key, ownerUserId, ids, live: false, cancellationToken);
            dbContext.PlanPausedListings.AddRange(ids.Select(id => new PlanPausedListing
            {
                OwnerUserId = ownerUserId,
                Area = area.Key,
                ListingId = id,
                PausedAt = now,
            }));
        }

        await dbContext.SaveChangesAsync(cancellationToken);
    }

    /// <summary>
    /// Ends every paid plan whose time is up and pauses what it alone allowed. A business whose other
    /// areas cannot be reached is left for the next run; nothing is half-done.
    /// </summary>
    public async Task<int> EndDuePlansAsync(DateTimeOffset now, CancellationToken cancellationToken)
    {
        var due = await dbContext.BusinessSubscriptions
            .Where(s => s.State == SubscriptionStatus.Active && s.EndsAt <= now)
            .ToListAsync(cancellationToken);
        var ended = 0;
        foreach (var owner in due.GroupBy(s => s.OwnerUserId))
        {
            try
            {
                await PauseBeyondAllowanceAsync(owner.Key, now, cancellationToken);
                foreach (var plan in owner)
                {
                    plan.State = SubscriptionStatus.Ended;
                }

                await dbContext.SaveChangesAsync(cancellationToken);
                ended += owner.Count();
            }
            catch (AreaUnavailableException ex)
            {
                logger.LogWarning(ex, "Plan end for {Owner} waits: {Area} could not be reached.", owner.Key, ex.Area);
            }
        }

        return ended;
    }

    private async Task SetLiveAsync(
        ListingArea area, Guid ownerUserId, List<Guid> ids, bool live, CancellationToken cancellationToken)
    {
        if (area != ListingArea.Service)
        {
            await (live
                ? areaListings.ResumeAsync(area, ownerUserId, ids, cancellationToken)
                : areaListings.PauseAsync(area, ownerUserId, ids, cancellationToken));
            return;
        }

        var services = await dbContext.BusinessServices
            .Where(s => ids.Contains(s.Id) && s.BusinessOwnerProfile.UserId == ownerUserId)
            .ToListAsync(cancellationToken);
        foreach (var service in services)
        {
            service.IsActive = live;
        }
    }
}
