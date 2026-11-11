using Microsoft.EntityFrameworkCore;
using Zuno.Marketplace.Domain.Entities;

namespace Zuno.Marketplace.Application.Common;

/// <summary>The Marketplace database — its own, apart from the Service and Rent databases.</summary>
public interface IMarketplaceDbContext
{
    public DbSet<MarketplaceCategory> Categories { get; }

    public DbSet<MarketplaceCategoryField> CategoryFields { get; }

    public DbSet<MarketplacePost> Posts { get; }

    public DbSet<MarketplacePostMedia> PostMedia { get; }

    public DbSet<MarketplaceBusiness> Businesses { get; }

    public DbSet<MarketplacePlan> Plans { get; }

    public DbSet<MarketplaceBusinessPlan> BusinessPlans { get; }

    public DbSet<MarketplacePostKindOption> PostKinds { get; }

    public DbSet<MarketplacePostStatusOption> PostStatuses { get; }

    public DbSet<MarketplacePostTransition> PostTransitions { get; }

    public DbSet<RefDistrict> Districts { get; }

    public Task<int> SaveChangesAsync(CancellationToken cancellationToken = default);

    /// <summary>
    /// Runs [work] in one transaction holding a lock for this business, so two saves at once cannot
    /// both pass the plan's post limit: the second waits, then counts the first one's post.
    /// </summary>
    public Task<T> WithOwnerLockAsync<T>(Guid ownerUserId, Func<Task<T>> work, CancellationToken cancellationToken);
}

/// <summary>
/// The Service API, asked with the caller's own login: the business's name and verification. The
/// token carries only an id, so names come from where accounts live — never from what the app sends.
/// </summary>
public interface IServiceDirectory
{
    /// <summary>The signed-in business's profile; null when there is none or the API cannot be reached.</summary>
    public Task<ServiceBusiness?> GetCurrentBusinessAsync(CancellationToken cancellationToken);
}

public record ServiceBusiness(string Name, string? LogoUrl, bool IsVerified);

/// <summary>Who is calling, read from the shared login's token.</summary>
public interface ICurrentUser
{
    public Guid? UserId { get; }
}

/// <summary>Where a post's photos are kept.</summary>
public interface IMarketplaceMediaStorage
{
    /// <summary>Saves a photo into <paramref name="slot"/>, replacing what was there. Returns its public URL.</summary>
    public Task<string> SaveImageAsync(Guid postId, int slot, Stream content, string fileExtension, CancellationToken cancellationToken);

    /// <summary>Deletes the file behind a URL this storage returned, if it is still there.</summary>
    public void Delete(string publicUrl);
}
