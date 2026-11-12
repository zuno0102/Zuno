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
