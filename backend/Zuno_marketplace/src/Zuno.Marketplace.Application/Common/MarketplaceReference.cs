using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Caching.Memory;
using Microsoft.Extensions.Options;
using Zuno.Marketplace.Domain.Entities;

namespace Zuno.Marketplace.Application.Common;

/// <summary>
/// The rarely changing rows every request reads — categories with their fields, and the post
/// transitions — read once and cached. The admin screens clear the cache when they change a row.
/// </summary>
public class MarketplaceReference(IMarketplaceDbContext dbContext, IMemoryCache cache, IOptions<MarketplaceSettings> settings)
{
    public const string CategoriesKey = "marketplace:categories";

    public const string TransitionsKey = "marketplace:transitions";

    /// <summary>Every category, active or not, each with all its sub-categories and fields, in display order.</summary>
    public Task<IReadOnlyList<MarketplaceCategory>> CategoriesAsync(CancellationToken cancellationToken) =>
        CachedAsync<MarketplaceCategory>(
            CategoriesKey,
            async () => await dbContext.Categories
                .AsNoTracking()
                .Include(c => c.SubCategories)
                .Include(c => c.Fields)
                .OrderBy(c => c.DisplayOrder)
                .ThenBy(c => c.Name)
                .ToListAsync(cancellationToken));

    public Task<IReadOnlyList<MarketplacePostTransition>> TransitionsAsync(CancellationToken cancellationToken) =>
        CachedAsync<MarketplacePostTransition>(
            TransitionsKey,
            async () => await dbContext.PostTransitions.AsNoTracking().OrderBy(t => t.DisplayOrder).ToListAsync(cancellationToken));

    public Task<IReadOnlyList<MarketplaceOrderStatusOption>> OrderStatusesAsync(CancellationToken cancellationToken) =>
        CachedAsync<MarketplaceOrderStatusOption>(
            "marketplace:order-statuses",
            async () => await dbContext.OrderStatuses.AsNoTracking().OrderBy(s => s.DisplayOrder).ToListAsync(cancellationToken));

    public Task<IReadOnlyList<MarketplaceOrderTransition>> OrderTransitionsAsync(CancellationToken cancellationToken) =>
        CachedAsync<MarketplaceOrderTransition>(
            "marketplace:order-transitions",
            async () => await dbContext.OrderTransitions.AsNoTracking().OrderBy(t => t.DisplayOrder).ToListAsync(cancellationToken));

    /// <summary>Every courier, switched-off ones too: an order shipped with one still shows its name and link.</summary>
    public Task<IReadOnlyList<MarketplaceCourier>> CouriersAsync(CancellationToken cancellationToken) =>
        CachedAsync<MarketplaceCourier>(
            "marketplace:couriers",
            async () => await dbContext.Couriers.AsNoTracking().OrderBy(c => c.DisplayOrder).ThenBy(c => c.Name).ToListAsync(cancellationToken));

    public Task<IReadOnlyList<MarketplacePaymentMethodOption>> PaymentMethodsAsync(CancellationToken cancellationToken) =>
        CachedAsync<MarketplacePaymentMethodOption>(
            "marketplace:payment-methods",
            async () => await dbContext.PaymentMethods.AsNoTracking().OrderBy(m => m.DisplayOrder).ToListAsync(cancellationToken));

    public Task<IReadOnlyList<MarketplaceB2BRequestStatusOption>> B2BRequestStatusesAsync(CancellationToken cancellationToken) =>
        CachedAsync<MarketplaceB2BRequestStatusOption>(
            "marketplace:b2b-request-statuses",
            async () => await dbContext.B2BRequestStatuses.AsNoTracking().OrderBy(s => s.DisplayOrder).ToListAsync(cancellationToken));

    /// <summary>Drops the cached categories, so the next read sees an admin's change at once.</summary>
    public void ForgetCategories() => cache.Remove(CategoriesKey);

    private async Task<IReadOnlyList<T>> CachedAsync<T>(string key, Func<Task<List<T>>> load)
    {
        if (cache.TryGetValue(key, out IReadOnlyList<T>? cached) && cached is not null)
        {
            return cached;
        }

        IReadOnlyList<T> rows = await load();
        cache.Set(key, rows, TimeSpan.FromSeconds(settings.Value.CategoryCacheSeconds));
        return rows;
    }
}
